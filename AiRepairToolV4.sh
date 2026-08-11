#!/data/data/com.termux/files/usr/bin/bash

# =========================
# ANTI KILL ANDROID
# =========================
termux-wake-lock

# Matikan Job Control bawaan bash agar tidak mengacak tampilan progress bar
set +m

# ==============================================================================
# WINK AI REPAIR TOOL (TERMUX EDITION) - FIXED DIVISION BY ZERO & PRESETS
# ==============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# =============================================================
# VISUAL PROGRESS BAR FUNCTION (ANTI-SCROLL & AUTO-FIT TERMUX)
# =============================================================
show_repair_progress() {
    local title="$1"
    local target_file="$2"
    local pid="$3"
    local total_sec="$4"
    local log_file="$5"

    echo -e "${CYAN}[*] $title...${NC}"

    # Sanitasi durasi
    total_sec=${total_sec%.*}
    if [ -z "$total_sec" ] || [ "$total_sec" -le 0 ]; then
        total_sec=1
    fi

    while kill -0 "$pid" 2>/dev/null; do
        # 1. Ukuran MB real-time
        local current_bytes=0
        if [ -f "$target_file" ]; then
            current_bytes=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
        fi
        local current_mb=$(awk -v b="$current_bytes" 'BEGIN { printf "%.1f", b / 1048576 }')

        # 2. Parsing log FFmpeg
        local time_str="00:00:00"
        local speed_disp="1.0x"
        
        if [ -f "$log_file" ]; then
            time_str=$(grep -o "time=[0-9:\.]*" "$log_file" | tail -n 1 | cut -d'=' -f2)
            speed_disp=$(grep -o "speed=[0-9\.]*x" "$log_file" | tail -n 1 | cut -d'=' -f2)
            [ -z "$time_str" ] && time_str="00:00:00"
            [ -z "$speed_disp" ] && speed_disp="1.0x"
        fi

        # 3. Hitung Detik & Persentase
        local h=$(echo "$time_str" | awk -F: '{print $1}')
        local m=$(echo "$time_str" | awk -F: '{print $2}')
        local s=$(echo "$time_str" | awk -F: '{print $3}' | cut -d. -f1)
        
        h=${h:-0}; m=${m:-0}; s=${s:-0}
        local current_sec=$(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))

        local percent=$(( (current_sec * 100) / total_sec ))
        [ $percent -gt 100 ] && percent=100
        [ $percent -lt 0 ] && percent=0

        # 4. Hitung ETA
        local raw_spd=$(echo "$speed_disp" | tr -d 'x')
        local eta_disp="--:--"
        
        if [ $(echo "$raw_spd > 0" | awk '{print ($1 > 0)}') -eq 1 ] && [ $percent -lt 100 ]; then
            local rem_sec=$(awk -v tot="$total_sec" -v cur="$current_sec" -v spd="$raw_spd" 'BEGIN {
                rem = (tot - cur) / spd;
                if (rem < 0) rem = 0;
                print int(rem);
            }')
            local eta_m=$(( rem_sec / 60 ))
            local eta_s=$(( rem_sec % 60 ))
            eta_disp=$(printf "%02d:%02d" $eta_m $eta_s)
        elif [ $percent -eq 100 ]; then
            eta_disp="00:00"
        fi

        # 5. Deteksi Otomatis Lebar Layar Termux (Agar tidak melipat ke baris baru)
        local term_cols=$(tput cols 2>/dev/null || echo 80)
        # Sisa ruang untuk bar [===] setelah dikurangi panjang teks (~40 karakter)
        local width=$(( term_cols - 42 ))
        [ $width -lt 10 ] && width=10  # Minimal lebar bar 10 karakter

        # 6. Generator Visual Bar
        local filled=$(( (percent * width) / 100 ))
        local empty=$(( width - filled ))
        local bar=""
        
        if [ $filled -gt 0 ]; then
            bar=$(printf "%${filled}s" "" | tr ' ' '=')
            if [ $filled -lt $width ]; then
                bar="${bar:0:-1}>"
            fi
        fi
        local pad=$(printf "%${empty}s" "")

        # Format diperingkas agar MUAT di 1 baris layar HP kecil sekalipun
        # ANSI Escape \033[2K (hapus seluruh baris) + \r (kembali ke awal baris)
        printf "\033[2K\r[%s%s] %2d%%|%sMB|%s|ETA:%s" "$bar" "$pad" "$percent" "$current_mb" "$speed_disp" "$eta_disp"
        
        sleep 0.4
    done

    # Tampilan saat Selesai
    local final_bytes=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
    local final_mb=$(awk -v b="$final_bytes" 'BEGIN { printf "%.1f", b / 1048576 }')

    printf "\033[2K\r[====================] 100%% | Total: %s MB | Selesai!\n" "$final_mb"
}

# Outer Loop untuk fitur pengulangan skrip
while true; do

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}       WINK AI REPAIR TOOL (TERMUX EDITION)         ${NC}"
echo -e "${CYAN}====================================================${NC}"

# ==============================================================================
# CEK DEPENDENCIES
# ==============================================================================
echo -e "${PURPLE}--- MEMERIKSA BAHAN/DEPENDENCIES ---${NC}"

if command -v ffmpeg &> /dev/null && command -v ffprobe &> /dev/null; then
    echo -e "1. FFmpeg & FFprobe  : ${GREEN}[✓] Sudah terinstal${NC}"
else
    echo -e "1. FFmpeg & FFprobe  : ${YELLOW}[!] Belum terinstal, menginstal otomatis...${NC}"
    pkg update -y && pkg install ffmpeg -y
fi

if command -v tput &> /dev/null; then
    echo -e "2. Ncurses-utils    : ${GREEN}[✓] Sudah terinstal${NC}"
else
    echo -e "2. Ncurses-utils    : ${YELLOW}[!] Belum terinstal, menginstal otomatis...${NC}"
    pkg install ncurses-utils -y
fi

echo -e "${PURPLE}------------------------------------${NC}\n"

# ==============================================================================
# VALIDASI INPUT FILE VIDEO
# ==============================================================================
while true; do
    read -p "Masukkan nama/path file video input: " INPUT
    INPUT=$(echo "$INPUT" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    if [ -f "$INPUT" ]; then
        break
    else
        echo -e "${YELLOW}File '${INPUT}' tidak ditemukan! Silakan periksa kembali.${NC}\n"
    fi
done

BASENAME=$(basename "$INPUT")
ORIGINAL_DIR=$(dirname "$INPUT")
FILENAME_NO_EXT="${BASENAME%.*}"

# Sanitasi Nama Folder & File
SAFE_NAME=$(echo "$FILENAME_NO_EXT" | sed 's/[^a-zA-Z0-9_-]/_/g')

# Default Path Output Ke Internal Storage HP
DEFAULT_OUT_DIR="/storage/emulated/0/Movies/AI-REPAIR-TERMUX/${SAFE_NAME}"

# ==============================================================================
# BACA INFO DETAIL VIDEO ASLI
# ==============================================================================
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "$INPUT")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 "$INPUT")
DAR=$(ffprobe -v error -select_streams v:0 -show_entries stream=display_aspect_ratio -of csv=s=x:p=0 "$INPUT")
V_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$INPUT")
RAW_V_BITRATE=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=s=x:p=0 "$INPUT")
A_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$INPUT")
RAW_A_BITRATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of csv=s=x:p=0 "$INPUT")
DURATION_SEC=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
RAW_ORIGINAL_SIZE=$(stat -c%s "$INPUT" 2>/dev/null || echo 0)

if [ -z "$DAR" ] || [ "$DAR" == "N/A" ]; then DAR="${WIDTH}:${HEIGHT}"; fi

# Format Durasi ke 00:00:00
DISPLAY_DURATION=$(awk -v dur="$DURATION_SEC" 'BEGIN {
    if (dur ~ /^[0-9]+(\.[0-9]+)?$/ && dur > 0) {
        h = int(dur / 3600);
        m = int((dur % 3600) / 60);
        s = int(dur % 60);
        printf "%02d:%02d:%02d", h, m, s;
    } else {
        print "00:00:00";
    }
}')

# Helper Fungsi Format Bitrate (Kbps vs Mbps)
format_bitrate() {
    local raw_br="$1"
    if [[ ! "$raw_br" =~ ^[0-9]+$ ]] || [ "$raw_br" -eq 0 ]; then
        echo "N/A"
    else
        awk -v br="$raw_br" 'BEGIN {
            kb = br / 1000;
            if (kb >= 1000) {
                printf "%.1f Mbps", kb / 1000;
            } else {
                printf "%d Kbps", kb;
            }
        }'
    fi
}

# Helper Ukuran File
format_size() {
    local raw_bytes="$1"
    if [[ ! "$raw_bytes" =~ ^[0-9]+$ ]] || [ "$raw_bytes" -eq 0 ]; then
        echo "N/A"
    else
        awk -v b="$raw_bytes" 'BEGIN { printf "%.2f MB", b / (1024 * 1024); }'
    fi
}

# Helper Generasi Scale Filter Berdasarkan Video Input (Otomatis Sisi Terpendek)
get_smart_scale_expr() {
    local target_res="$1"
    # Jika Square (1:1)
    if [ "$WIDTH" -eq "$HEIGHT" ]; then
        echo "scale=${target_res}:${target_res}:flags=lanczos"
    # Jika Landscape (Width > Height) Contoh: 16:9, 4:3
    elif [ "$WIDTH" -gt "$HEIGHT" ]; then
        echo "scale=-2:${target_res}:flags=lanczos"
    # Jika Portrait (Height > Width) Contoh: 9:16, 3:4, 4:5
    else
        echo "scale=${target_res}:-2:flags=lanczos"
    fi
}

DISPLAY_V_BITRATE=$(format_bitrate "$RAW_V_BITRATE")

if [ -z "$A_CODEC" ] || [ "$A_CODEC" == "N/A" ]; then A_CODEC="Tidak ada audio / N/A"; fi
DISPLAY_A_BITRATE=$(format_bitrate "$RAW_A_BITRATE")
DISPLAY_ORIGINAL_SIZE=$(format_size "$RAW_ORIGINAL_SIZE")

SHORT_DIM=$(( WIDTH < HEIGHT ? WIDTH : HEIGHT ))
if [ "$SHORT_DIM" -ge 2160 ]; then DEFAULT_RES_PREFIX="4K"
elif [ "$SHORT_DIM" -ge 1440 ]; then DEFAULT_RES_PREFIX="2K"
elif [ "$SHORT_DIM" -ge 1080 ]; then DEFAULT_RES_PREFIX="1080P"
elif [ "$SHORT_DIM" -ge 720 ]; then DEFAULT_RES_PREFIX="720P"
else DEFAULT_RES_PREFIX="${SHORT_DIM}P"; fi

echo ""
echo -e "${PURPLE}--- INFORMASI VIDEO ASLI ---${NC}"
echo -e "Nama File          : ${CYAN}${BASENAME}${NC}"
echo -e "Durasi Video       : ${CYAN}${DISPLAY_DURATION}${NC}"
echo -e "Ukuran File        : ${CYAN}${DISPLAY_ORIGINAL_SIZE}${NC}"
echo -e "Resolusi           : ${CYAN}${WIDTH}x${HEIGHT}${NC}"
echo -e "Aspek Rasio        : ${CYAN}${DAR}${NC}"
echo -e "Codec Video        : ${CYAN}${V_CODEC}${NC}"
echo -e "Bitrate Video Asli : ${CYAN}${DISPLAY_V_BITRATE}${NC}"
echo -e "Format Audio       : ${CYAN}${A_CODEC}${NC}"
echo -e "Bitrate Audio      : ${CYAN}${DISPLAY_A_BITRATE}${NC}"
echo -e "${PURPLE}----------------------------${NC}"

# ==============================================================================
# PILIHAN KELIPATAN BITRATE VIDEO (SETELAH INFO DETAIL VIDEO)
# ==============================================================================
echo -e "\n${BLUE}--- PILIHAN KELIPATAN BITRATE VIDEO ---${NC}"
echo "1. 2x"
echo "2. 3x"
echo "3. 4x"
echo "4. 5x"
echo "5. Custom (Maksimal 12)"
while true; do
    read -p "Pilih kelipatan bitrate (1-5): " BITRATE_OPT
    case $BITRATE_OPT in
        1) MULTIPLIER=2; break ;;
        2) MULTIPLIER=3; break ;;
        3) MULTIPLIER=4; break ;;
        4) MULTIPLIER=5; break ;;
        5)
            while true; do
                read -p "Masukkan angka custom (1-12): " CUSTOM_MULT
                if [[ "$CUSTOM_MULT" =~ ^[0-9]+$ ]] && [ "$CUSTOM_MULT" -ge 1 ] && [ "$CUSTOM_MULT" -le 12 ]; then
                    MULTIPLIER=$CUSTOM_MULT
                    break
                else
                    echo -e "${YELLOW}Masukkan angka bulat antara 1 sampai 12!${NC}"
                fi
            done
            break
            ;;
        *) echo -e "${YELLOW}Pilihan tidak valid! Pilih angka 1 sampai 5.${NC}" ;;
    esac
done

# Hitung Target Bitrate Berdasarkan Multiplier
if [[ ! "$RAW_V_BITRATE" =~ ^[0-9]+$ ]] || [ "$RAW_V_BITRATE" -eq 0 ]; then
    TARGET_V_BITRATE="$((10000 * MULTIPLIER))k"
    DISPLAY_TARGET_BITRATE="Default ke $(format_bitrate $((10000000 * MULTIPLIER)))"
else
    CALC_BITRATE=$(( RAW_V_BITRATE * MULTIPLIER ))
    TARGET_V_BITRATE="$(( CALC_BITRATE / 1000 ))k"
    DISPLAY_TARGET_BITRATE=$(format_bitrate "$CALC_BITRATE")
fi

echo -e "Bitrate Target (${MULTIPLIER}x) : ${GREEN}${DISPLAY_TARGET_BITRATE}${NC}"

# Variable Status Fitur untuk Log & Summary
LOG_HD="NONAKTIF"
LOG_SUPER_RES="NONAKTIF"
LOG_NIGHT="NONAKTIF"
LOG_COLOR="NONAKTIF"
LOG_NOISE="NONAKTIF"
LOG_SMOOTH="NONAKTIF"
SCORE_IMPROVEMENT=0

# Helper fungsi subnet HD / UHD
select_hd_level() {
    while true; do
        echo -e "\nPilih Level HD Enhancement:"
        echo "1. Rendah"
        echo "2. Sedang"
        echo "3. Tinggi"
        read -p "Pilihan level (1-3): " HD_SUB
        case $HD_SUB in
            1) VF_RET="unsharp=3:3:0.8:3:3:0.0"; LOG_HD="AKTIF (HD Enhancement - Rendah)"; SCORE_IMP=15; break ;;
            2) VF_RET="unsharp=5:5:1.2:5:5:0.0"; LOG_HD="AKTIF (HD Enhancement - Sedang)"; SCORE_IMP=20; break ;;
            3) VF_RET="unsharp=7:7:1.5:7:7:0.0"; LOG_HD="AKTIF (HD Enhancement - Tinggi)"; SCORE_IMP=25; break ;;
            *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 sampai 3.${NC}" ;;
        esac
    done
}

select_uhd_level() {
    while true; do
        echo -e "\nPilih Level UHD Enhancement:"
        echo "1. Rendah"
        echo "2. Sedang"
        echo "3. Tinggi"
        echo "4. Sangat Tinggi"
        read -p "Pilihan level (1-4): " UHD_SUB
        case $UHD_SUB in
            1) VF_RET="unsharp=5:5:1.5:5:5:0.0"; LOG_HD="AKTIF (UHD Enhancement - Rendah)"; SCORE_IMP=25; break ;;
            2) VF_RET="unsharp=7:7:1.8:7:7:0.0"; LOG_HD="AKTIF (UHD Enhancement - Sedang)"; SCORE_IMP=30; break ;;
            3) VF_RET="unsharp=9:9:2.0:9:9:0.0"; LOG_HD="AKTIF (UHD Enhancement - Tinggi)"; SCORE_IMP=35; break ;;
            4) VF_RET="unsharp=11:11:2.5:11:11:0.0"; LOG_HD="AKTIF (UHD Enhancement - Sangat Tinggi)"; SCORE_IMP=45; break ;;
            *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 sampai 4.${NC}" ;;
        esac
    done
}

select_color_level() {
    while true; do
        echo -e "\nPilih Level AI Color Restoration:"
        echo "1. Rendah"
        echo "2. Sedang"
        echo "3. Tinggi"
        read -p "Pilihan level (1-3): " COL_SUB
        case $COL_SUB in
            1) VF_RET="eq=saturation=1.15:contrast=1.05:brightness=0.01"; LOG_COLOR="AKTIF (Rendah)"; SCORE_IMP=15; break ;;
            2) VF_RET="eq=saturation=1.25:contrast=1.10:brightness=0.02"; LOG_COLOR="AKTIF (Sedang)"; SCORE_IMP=25; break ;;
            3) VF_RET="eq=saturation=1.35:contrast=1.15:brightness=0.03"; LOG_COLOR="AKTIF (Tinggi)"; SCORE_IMP=35; break ;;
            *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 sampai 3.${NC}" ;;
        esac
    done
}

# Helper Submenu Super Resolution
select_super_res_level() {
    while true; do
        echo -e "\nPilih Target Resolusi Super Resolution:"
        echo "1. 1080p (Sisi Terpendek 1080px)"
        echo "2. 2K    (Sisi Terpendek 1440px)"
        echo "3. 4K    (Sisi Terpendek 2160px)"
        echo "4. Custom Resolution (Bebas Atur Width & Height)"
        read -p "Pilihan resolusi (1-4): " RES_OPT
        case $RES_OPT in
            1)
                RES_PREFIX="1080P"
                LOG_SUPER_RES="AKTIF (1080p)"
                SCALE_EXPR=$(get_smart_scale_expr 1080)
                SCORE_IMP=35
                break
                ;;
            2)
                RES_PREFIX="2K"
                LOG_SUPER_RES="AKTIF (2K)"
                SCALE_EXPR=$(get_smart_scale_expr 1440)
                SCORE_IMP=50
                break
                ;;
            3)
                RES_PREFIX="4K"
                LOG_SUPER_RES="AKTIF (4K)"
                SCALE_EXPR=$(get_smart_scale_expr 2160)
                SCORE_IMP=70
                break
                ;;
            4)
                echo -e "\n${CYAN}====================================================${NC}"
                echo -e "${GREEN}    PANDUAN UKURAN KELIPATAN ASPECT RATIO STANDAR   ${NC}"
                echo -e "${CYAN}====================================================${NC}"
                echo -e " 🔹 ${YELLOW}16:9 (Landscape Standard / YouTube)${NC}"
                echo -e "    - 720p  : 1280 x 720    | 1080p : 1920 x 1080"
                echo -e "    - 2K    : 2560 x 1440   | 4K    : 3840 x 2160"
                echo -e " 🔹 ${YELLOW}9:16 (Portrait / TikTok / Reels / Shorts)${NC}"
                echo -e "    - 720p  : 720 x 1280    | 1080p : 1080 x 1920"
                echo -e "    - 2K    : 1440 x 2560   | 4K    : 2160 x 3840"
                echo -e " 🔹 ${YELLOW}1:1  (Square / Instagram Feed)${NC}"
                echo -e "    - 720p  : 720 x 720     | 1080p : 1080 x 1080"
                echo -e "    - 2K    : 1440 x 1440   | 4K    : 2160 x 2160"
                echo -e " 🔹 ${YELLOW}3:4  (Portrait / Post Feed)${NC}"
                echo -e "    - 720p  : 720 x 960     | 1080p : 1080 x 1440"
                echo -e "    - 2K    : 1440 x 1920   | 4K    : 2160 x 2880"
                echo -e " 🔹 ${YELLOW}4:3  (Landscape TV / Klasik)${NC}"
                echo -e "    - 720p  : 960 x 720     | 1080p : 1440 x 1080"
                echo -e "    - 2K    : 1920 x 1440   | 4K    : 2880 x 2160"
                echo -e " 🔹 ${YELLOW}4:5  (Portrait IG Feed Optimal)${NC}"
                echo -e "    - 720p  : 720 x 900     | 1080p : 1080 x 1350"
                echo -e "    - 2K    : 1440 x 1800   | 4K    : 2160 x 2700"
                echo -e "${CYAN}====================================================${NC}\n"

                while true; do
                    read -p "Masukkan Lebar / Width (piksel, cth: 1080): " C_W
                    read -p "Masukkan Tinggi / Height (piksel, cth: 1920): " C_H
                    if [[ "$C_W" =~ ^[0-9]+$ ]] && [[ "$C_H" =~ ^[0-9]+$ ]] && [ "$C_W" -gt 0 ] && [ "$C_H" -gt 0 ]; then
                        RES_PREFIX="CUSTOM_${C_W}x${C_H}"
                        LOG_SUPER_RES="AKTIF (Custom ${C_W}x${C_H})"
                        SCALE_EXPR="scale=${C_W}:${C_H}:flags=lanczos"
                        SCORE_IMP=40
                        break
                    else
                        echo -e "${YELLOW}Width dan Height harus berupa angka bulat lebih besar dari 0!${NC}"
                    fi
                done
                break
                ;;
            *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 sampai 4.${NC}" ;;
        esac
    done
}

# ==============================================================================
# MENU UTAMA WITH VALIDATION LOOP
# ==============================================================================
RES_PREFIX="$DEFAULT_RES_PREFIX"

while true; do
    echo ""
    echo -e "${BLUE}--- MENU AI REPAIR ---${NC}"
    echo "1. HD Quality Enhancement / UHD Enhancement"
    echo "2. AI Night Scene Repair (Sedang / Tinggi)"
    echo "3. Smooth Motion (60 FPS / 120 FPS)"
    echo "4. Full Repair Combo (Custom Level & FPS)"
    echo "5. AI Color Restoration (Restorasi Warna & Kontras)"
    echo "6. Noise Reduction (Rendah / Sedang / Tinggi)"
    echo "7. Super Resolution (1080p / 2K / 4K / Custom - Auto Aspect Ratio)"
    echo "8. Custom Mode (Bebas Atur Semua Efek & Level)"
    read -p "Pilihan kamu (1-8): " CHOICE

    case $CHOICE in
        1)
            while true; do
                echo -e "\nPilih Mode Enhancer Video:"
                echo "1. HD Enhancement"
                echo "2. UHD / Ultra HD Enhancement"
                read -p "Pilihan mode (1-2): " HD_LVL
                case $HD_LVL in
                    1) select_hd_level; VF="$VF_RET"; SCORE_IMPROVEMENT=$SCORE_IMP; break ;;
                    2) select_uhd_level; VF="$VF_RET"; SCORE_IMPROVEMENT=$SCORE_IMP; break ;;
                    *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 atau 2.${NC}" ;;
                esac
            done
            break
            ;;

        2)
            while true; do
                echo -e "\nPilih Level AI Night Scene:"
                echo "1. Sedang (Gamma 1.3) | 2. Tinggi (Gamma 1.5)"
                read -p "Pilihan level (1-2): " NIGHT_LVL
                case $NIGHT_LVL in
                    1) VF="eq=gamma=1.3:saturation=1.2:contrast=1.1,hqdn3d=1.5:1.5:6:6"; LOG_NIGHT="AKTIF (Sedang)"; SCORE_IMPROVEMENT=30; break ;;
                    2) VF="eq=gamma=1.5:saturation=1.25:contrast=1.15,hqdn3d=2.0:2.0:7:7"; LOG_NIGHT="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=45; break ;;
                    *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 atau 2.${NC}" ;;
                esac
            done
            break
            ;;

        3)
            while true; do
                echo -e "\nPilih Target FPS:"
                echo "1. 60 FPS | 2. 120 FPS"
                read -p "Pilihan FPS (1-2): " FPS_OPT
                case $FPS_OPT in
                    1) VF="minterpolate=fps=60:mi_mode=mci"; LOG_SMOOTH="AKTIF (60 FPS)"; SCORE_IMPROVEMENT=40; break ;;
                    2) VF="minterpolate=fps=120:mi_mode=mci"; LOG_SMOOTH="AKTIF (120 FPS)"; SCORE_IMPROVEMENT=60; break ;;
                    *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1 atau 2.${NC}" ;;
                esac
            done
            break
            ;;

        4)
            echo -e "\n${CYAN}=== SETTING FULL REPAIR COMBO ===${NC}"
            while true; do
                echo "Pilih Mode HD Enhancement (1. HD Enhancement | 2. UHD Enhancement):"
                read -p "Pilihan: " C_HD
                case $C_HD in
                    1) select_hd_level; HD_F="$VF_RET"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP)); break ;;
                    2) select_uhd_level; HD_F="$VF_RET"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP)); break ;;
                    *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                esac
            done

            while true; do
                echo "Pilih Level Night Scene (1. Sedang | 2. Tinggi):"
                read -p "Pilihan: " C_NIGHT
                case $C_NIGHT in
                    1) NIGHT_F="eq=gamma=1.3:saturation=1.2:contrast=1.1"; LOG_NIGHT="AKTIF (Sedang)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 20)); break ;;
                    2) NIGHT_F="eq=gamma=1.5:saturation=1.25:contrast=1.15"; LOG_NIGHT="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 30)); break ;;
                    *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                esac
            done

            while true; do
                echo "Pilih Level Noise Reduction (1. Rendah | 2. Sedang | 3. Tinggi):"
                read -p "Pilihan: " C_NOISE
                case $C_NOISE in
                    1) NOISE_F="hqdn3d=1.0:1.0:4:4"; LOG_NOISE="AKTIF (Rendah)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 15)); break ;;
                    2) NOISE_F="hqdn3d=2.0:2.0:7:7"; LOG_NOISE="AKTIF (Sedang)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 25)); break ;;
                    3) NOISE_F="hqdn3d=3.5:3.5:10:10"; LOG_NOISE="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 35)); break ;;
                    *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                esac
            done

            while true; do
                echo "Pilih Target FPS (1. 60 FPS | 2. 120 FPS):"
                read -p "Pilihan: " C_FPS
                case $C_FPS in
                    1) FPS_F="minterpolate=fps=60:mi_mode=mci"; LOG_SMOOTH="AKTIF (60 FPS)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 30)); break ;;
                    2) FPS_F="minterpolate=fps=120:mi_mode=mci"; LOG_SMOOTH="AKTIF (120 FPS)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 50)); break ;;
                    *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                esac
            done

            VF="${HD_F},${NIGHT_F},${NOISE_F},${FPS_F}"
            break
            ;;

        5)
            select_color_level
            VF="$VF_RET"
            SCORE_IMPROVEMENT=$SCORE_IMP
            break
            ;;

        6)
            while true; do
                echo -e "\nPilih Level Noise Reduction:"
                echo "1. Rendah | 2. Sedang | 3. Tinggi"
                read -p "Pilihan level (1-3): " NOISE_LVL
                case $NOISE_LVL in
                    1) VF="hqdn3d=1.0:1.0:4:4"; LOG_NOISE="AKTIF (Rendah)"; SCORE_IMPROVEMENT=15; break ;;
                    2) VF="hqdn3d=2.0:2.0:7:7"; LOG_NOISE="AKTIF (Sedang)"; SCORE_IMPROVEMENT=25; break ;;
                    3) VF="hqdn3d=3.5:3.5:10:10"; LOG_NOISE="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=35; break ;;
                    *) echo -e "${YELLOW}Pilihan tidak valid! Masukkan angka 1, 2, atau 3.${NC}" ;;
                esac
            done
            break
            ;;

        7)
            select_super_res_level
            VF="${SCALE_EXPR},unsharp=5:5:1.0:5:5:0.0"
            SCORE_IMPROVEMENT=$SCORE_IMP
            break
            ;;

        8)
            echo -e "\n${CYAN}=== CUSTOM REPAIR BUILDER ===${NC}"
            FILTERS=()

            ask_yn() {
                local prompt="$1"
                local ans
                while true; do
                    read -p "$prompt (y/n): " ans
                    case $ans in
                        [Yy]*) return 0 ;;
                        [Nn]*) return 1 ;;
                        *) echo -e "${YELLOW}Harap jawab dengan 'y' atau 'n'.${NC}" ;;
                    esac
                done
            }

            if ask_yn "Gunakan HD / UHD Enhancement?"; then
                while true; do
                    echo "  Pilih Mode: 1. HD Enhancement | 2. UHD Enhancement"
                    read -p "  Pilihan: " C_HD
                    case $C_HD in
                        1) select_hd_level; FILTERS+=("$VF_RET"); SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP)); break ;;
                        2) select_uhd_level; FILTERS+=("$VF_RET"); SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP)); break ;;
                        *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                    esac
                done
            fi

            if ask_yn "Gunakan Super Resolution?"; then
                select_super_res_level
                FILTERS+=("$SCALE_EXPR")
                SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP))
            fi

            if ask_yn "Gunakan Night Scene Repair (Perbaiki Malam)?"; then
                while true; do
                    echo "  Pilih Level Night Scene: 1. Sedang | 2. Tinggi"
                    read -p "  Pilihan: " C_NIGHT
                    case $C_NIGHT in
                        1) FILTERS+=("eq=gamma=1.3:contrast=1.1"); LOG_NIGHT="AKTIF (Sedang)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 20)); break ;;
                        2) FILTERS+=("eq=gamma=1.5:contrast=1.15"); LOG_NIGHT="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 30)); break ;;
                        *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                    esac
                done
            fi

            if ask_yn "Gunakan Color Restoration (Penaik Warna)?"; then
                select_color_level
                FILTERS+=("$VF_RET")
                SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + SCORE_IMP))
            fi

            if ask_yn "Gunakan Noise Reduction (Pembersih Bintik)?"; then
                while true; do
                    echo "  Pilih Level Noise Reduction: 1. Rendah | 2. Sedang | 3. Tinggi"
                    read -p "  Pilihan: " C_NOISE
                    case $C_NOISE in
                        1) FILTERS+=("hqdn3d=1.0:1.0:4:4"); LOG_NOISE="AKTIF (Rendah)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 15)); break ;;
                        2) FILTERS+=("hqdn3d=2.0:2.0:7:7"); LOG_NOISE="AKTIF (Sedang)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 25)); break ;;
                        3) FILTERS+=("hqdn3d=3.5:3.5:10:10"); LOG_NOISE="AKTIF (Tinggi)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 35)); break ;;
                        *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                    esac
                done
            fi

            if ask_yn "Gunakan Smooth Motion (Frame Generation)?"; then
                while true; do
                    echo "  Pilih Target FPS: 1. 60 FPS | 2. 120 FPS"
                    read -p "  Pilihan: " C_FPS
                    case $C_FPS in
                        1) FILTERS+=("minterpolate=fps=60:mi_mode=mci"); LOG_SMOOTH="AKTIF (60 FPS)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 30)); break ;;
                        2) FILTERS+=("minterpolate=fps=120:mi_mode=mci"); LOG_SMOOTH="AKTIF (120 FPS)"; SCORE_IMPROVEMENT=$((SCORE_IMPROVEMENT + 50)); break ;;
                        *) echo -e "${YELLOW}Pilihan salah! Coba lagi.${NC}" ;;
                    esac
                done
            fi

            VF=""
            for f in "${FILTERS[@]}"; do
                if [ -z "$VF" ]; then VF="$f"; else VF="${VF},$f"; fi
            done

            if [ -z "$VF" ]; then
                echo -e "${YELLOW}Kamu tidak memilih efek apapun! Silakan atur kembali menu Custom Mode.${NC}"
            else
                break
            fi
            ;;

        *)
            echo -e "${YELLOW}Pilihan menu tidak valid! Harap pilih angka 1 sampai 8.${NC}"
            ;;
    esac
done

# Hitung Persentase Perbaikan Gabungan (Multipler Bitrate + Skor Fitur)
TOTAL_PERCENT_IMPROVEMENT=$(( (MULTIPLIER - 1) * 20 + SCORE_IMPROVEMENT ))

# ==============================================================================
# PILIHAN CODEC VIDEO OUTPUT WITH PRESET DINAMIS
# ==============================================================================
while true; do
    echo ""
    echo -e "${BLUE}--- PILIHAN CODEC VIDEO ---${NC}"
    echo "1. H.264 / AVC (Paling Kompatibel dengan semua HP/Sosmed)"
    echo "2. H.265 / HEVC (Kompresi Efisien, Ukuran File Lebih Kecil)"
    read -p "Pilih Codec Output (1-2): " CODEC_OPT

    case $CODEC_OPT in
        1) 
            TARGET_CODEC="libx264"
            DISPLAY_CODEC="H.264 / AVC"
            while true; do
                echo -e "\nPilih Preset H.264:"
                echo "1. Fast   (Proses Cepat)"
                echo "2. Medium (Seimbang)"
                echo "3. Slow   (Hasil Lebih Bagus)"
                read -p "Pilihan preset (1-3): " PRESET_OPT
                case $PRESET_OPT in
                    1) TARGET_PRESET="fast"; break ;;
                    2) TARGET_PRESET="medium"; break ;;
                    3) TARGET_PRESET="slow"; break ;;
                    *) echo -e "${YELLOW}Pilihan tidak valid! Pilih angka 1 sampai 3.${NC}" ;;
                esac
            done
            break 
            ;;
        2) 
            TARGET_CODEC="libx265"
            DISPLAY_CODEC="H.265 / HEVC"
            TARGET_PRESET="ultrafast"
            break 
            ;;
        *) 
            echo -e "${YELLOW}Pilihan tidak valid! Harap masukkan angka 1 atau 2.${NC}" 
            ;;
    esac
done

# Fitur Timpa Video Asli
echo ""
echo -e "${BLUE}--- OPSI TIMPA VIDEO ASLI ---${NC}"
echo "Apakah anda ingin menghapus video asli setelah proses selesai?"
echo "1. Ya (Hapus video asli, simpan hasil perbaikan di folder video asli)"
echo "2. Tidak (Tetap simpan video asli)"
while true; do
    read -p "Pilihan kamu (1-2): " OVERWRITE_OPT
    case $OVERWRITE_OPT in
        1) 
            REMOVE_ORIGINAL="YA"
            OUT_DIR="$ORIGINAL_DIR"
            break 
            ;;
        2) 
            REMOVE_ORIGINAL="TIDAK"
            OUT_DIR="$DEFAULT_OUT_DIR"
            mkdir -p "$OUT_DIR"
            break 
            ;;
        *) echo -e "${YELLOW}Pilihan tidak valid! Pilih angka 1 atau 2.${NC}" ;;
    esac
done

OUTPUT_FILE="${OUT_DIR}/${RES_PREFIX}_${SAFE_NAME}.mp4"
LOG_FILE="${OUT_DIR}/${SAFE_NAME}.log"

# ==============================================================================
# WRITE SUMMARY HEADER TO LOG FILE
# ==============================================================================
cat <<EOF > "$LOG_FILE"
======================================================================
                  WINK AI REPAIR TOOL - PROCESS LOG                   
======================================================================
Tanggal & Waktu Execution : $(date '+%Y-%m-%d %H:%M:%S')

[INFORMASI VIDEO ASLI]
- Nama File Input    : ${BASENAME}
- Durasi Video       : ${DISPLAY_DURATION}
- Ukuran Asli        : ${DISPLAY_ORIGINAL_SIZE}
- Resolusi Asli      : ${WIDTH}x${HEIGHT} (${DAR})
- Codec Asli         : ${V_CODEC}
- Bitrate Asli       : ${DISPLAY_V_BITRATE}
- Audio Format       : ${A_CODEC} (${DISPLAY_A_BITRATE})

[CONFIGURASI RENDER TARGET]
- Nama File Output   : ${RES_PREFIX}_${SAFE_NAME}.mp4
- Codec Output       : ${DISPLAY_CODEC} (${TARGET_CODEC})
- Preset Output      : ${TARGET_PRESET}
- Target Bitrate     : ${DISPLAY_TARGET_BITRATE} (${MULTIPLIER}x)
- Filter Graph (VF)  : ${VF}

[STATUS RINGKASAN FITUR AI]
1. HD Quality Enhancement : ${LOG_HD}
2. Super Resolution       : ${LOG_SUPER_RES}
3. AI Night Scene Repair  : ${LOG_NIGHT}
4. Color Restoration      : ${LOG_COLOR}
5. Noise Reduction        : ${LOG_NOISE}
6. Smooth Motion (FPS)    : ${LOG_SMOOTH}
======================================================================

--- FFMPEG NATIVE PROCESS LOG ---
EOF

echo -e "\n${YELLOW}Memproses video... Output akan disimpan ke:${NC}"
echo -e "${PURPLE}${OUTPUT_FILE}${NC}\n"

# ==============================================================================
# FFMPEG EXECUTION WITH VISUAL PROGRESS
# ==============================================================================

# Jalankan FFmpeg di background & redirect output ke log
(
    ffmpeg -hide_banner -y -i "$INPUT" -vf "$VF" \
      -c:v "$TARGET_CODEC" -b:v "$TARGET_V_BITRATE" -preset "$TARGET_PRESET" \
      -c:a aac -b:a 128k "$OUTPUT_FILE" >> "$LOG_FILE" 2>&1
) &
FFMPEG_PID=$!

# Panggil fungsi Progress Bar Real-Time
show_repair_progress "Memproses AI Repair Video" "$OUTPUT_FILE" "$FFMPEG_PID" "$DURATION_SEC" "$LOG_FILE"

wait $FFMPEG_PID
STATUS=$?

echo "" 

if [ $STATUS -eq 0 ]; then
    FINAL_SIZE_RAW=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo 0)
    FINAL_SIZE_DISP=$(format_size "$FINAL_SIZE_RAW")
    
    # Baca data teknis video sesudah perbaikan (After)
    OUT_WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=s=x:p=0 "$OUTPUT_FILE")
    OUT_HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 "$OUTPUT_FILE")
    OUT_V_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$OUTPUT_FILE")
    OUT_RAW_V_BR=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=s=x:p=0 "$OUTPUT_FILE")
    OUT_A_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$OUTPUT_FILE")
    OUT_RAW_A_BR=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of csv=s=x:p=0 "$OUTPUT_FILE")

    OUT_DISPLAY_V_BR=$(format_bitrate "$OUT_RAW_V_BR")
    OUT_DISPLAY_A_BR=$(format_bitrate "$OUT_RAW_A_BR")

    # Eksekusi hapus video asli jika disetujui
    if [ "$REMOVE_ORIGINAL" == "YA" ]; then
        rm -f "$INPUT"
        echo -e "${YELLOW}-> Video asli telah dihapus dan diganti dengan hasil perbaikan.${NC}"
    fi

    # Display Ringkasan Perbandingan Before vs After
    echo -e "\n${GREEN}====================================================${NC}"
    echo -e "${GREEN}             PROSES SELESAI & HASIL                 ${NC}"
    echo -e "${GREEN}====================================================${NC}"
    
    echo -e "${PURPLE}[ INFORMASI VIDEO (BEFORE) ]${NC}"
    echo -e " Nama File Input    : ${CYAN}${BASENAME}${NC}"
    echo -e " Durasi Video       : ${CYAN}${DISPLAY_DURATION}${NC}"
    echo -e " Ukuran File        : ${CYAN}${DISPLAY_ORIGINAL_SIZE}${NC}"
    echo -e " Resolusi Asli      : ${CYAN}${WIDTH}x${HEIGHT}${NC}"
    echo -e " Codec Video        : ${CYAN}${V_CODEC}${NC}"
    echo -e " Bitrate Video Asli : ${CYAN}${DISPLAY_V_BITRATE}${NC}"
    echo -e " Format Audio       : ${CYAN}${A_CODEC}${NC}"
    echo -e " Bitrate Audio      : ${CYAN}${DISPLAY_A_BITRATE}${NC}"
    
    echo -e "\n${BLUE}[ INFORMASI VIDEO (AFTER) ]${NC}"
    echo -e " Nama File Output   : ${CYAN}${RES_PREFIX}_${SAFE_NAME}.mp4${NC}"
    echo -e " Durasi Video       : ${CYAN}${DISPLAY_DURATION}${NC}"
    echo -e " Ukuran File        : ${CYAN}${FINAL_SIZE_DISP}${NC}"
    echo -e " Resolusi Hasil     : ${CYAN}${OUT_WIDTH}x${OUT_HEIGHT}${NC}"
    echo -e " Codec Video        : ${CYAN}${OUT_V_CODEC}${NC}"
    echo -e " Bitrate Video AI   : ${CYAN}${OUT_DISPLAY_V_BR}${NC}"
    echo -e " Format Audio       : ${CYAN}${OUT_A_CODEC}${NC}"
    echo -e " Bitrate Audio      : ${CYAN}${OUT_DISPLAY_A_BR}${NC}"
    echo -e " Perbaikan Total AI : ${GREEN}+${TOTAL_PERCENT_IMPROVEMENT}% (Kualitas & Peningkatan AI Visual)${NC}"

    echo -e "\n${GREEN}====================================================${NC}"
    echo -e "${CYAN} Folder : ${OUT_DIR}${NC}"
    echo -e "${CYAN} Video  : ${RES_PREFIX}_${SAFE_NAME}.mp4${NC}"
    echo -e "${CYAN} Log    : ${SAFE_NAME}.log${NC}"
    echo -e "${GREEN}====================================================${NC}"
else
    echo -e "\n${YELLOW}Terjadi kesalahan saat memproses video. Cek file log di:${NC}"
    echo -e "${CYAN}${LOG_FILE}${NC}"
fi

# ==============================================================================
# FITUR ULANG SKRIP DENGAN VIDEO LAIN
# ==============================================================================
echo ""
echo -e "${PURPLE}Apakah anda ingin melanjutkan AI Repair Tool dengan video yang berbeda?${NC}"
echo "1. Ya"
echo "2. Keluar skrip"
while true; do
    read -p "Pilihan kamu (1-2): " REPEAT_OPT
    case $REPEAT_OPT in
        1) break ;;
        2) 
            echo -e "\n${GREEN}Terima kasih telah menggunakan Wink AI Repair Tool! Sampai jumpa.${NC}"
            exit 0
            ;;
        *) echo -e "${YELLOW}Pilihan tidak valid! Pilih angka 1 atau 2.${NC}" ;;
    esac
done

done
