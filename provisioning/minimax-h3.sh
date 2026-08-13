#!/bin/bash
# This file will be sourced in init.sh (ai-dock/comfyui on Vast.ai).
# MiniMax H3: T2V + I2V (fl2va pruned BF16 + INT8 convrot TE + stock VAEs).
# Models are NOT baked into the image; they download to /workspace on first boot.

HF_REPO="Comfy-Org/MiniMax-H3"
DISK_GB_REQUIRED=150

APT_PACKAGES=()
PIP_PACKAGES=("huggingface_hub[cli]")
NODES=()

# name|relative_path|min_bytes
H3_FILES=(
    "minimax_h3_fl2va_pruned_bf16.safetensors|diffusion_models/minimax_h3_fl2va_pruned_bf16.safetensors|40000000000"
    "qwen3vl_32b_minimax_h3_int8_convrot.safetensors|text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors|24000000000"
    "minimax_h3_video_vae_fp16.safetensors|vae/minimax_h3_video_vae_fp16.safetensors|4000000000"
    "minimax_h3_audio_vae_fp32.safetensors|vae/minimax_h3_audio_vae_fp32.safetensors|500000000"
)

function pip_install() {
    if [[ -n "${MAMBA_BASE:-}" ]]; then
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    elif [[ -n "${COMFYUI_VENV_PIP:-}" ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        pip install --no-cache-dir "$@"
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#  Provisioning: ComfyUI + MiniMax H3        #\n"
    printf "#  ~71 GB download on first boot             #\n"
    printf "##############################################\n\n"
    if [[ -n "${DISK_GB_ALLOCATED:-}" && "${DISK_GB_ALLOCATED}" -lt "${DISK_GB_REQUIRED}" ]]; then
        printf "WARNING: allocated disk (%sGB) is below recommended %sGB\n" \
            "${DISK_GB_ALLOCATED}" "${DISK_GB_REQUIRED}"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete: ComfyUI will start now\n"
    printf "Open Template Library -> Video -> MiniMax H3 T2V / I2V\n\n"
}

function provisioning_activate_env() {
    WORKSPACE="${WORKSPACE:-/workspace}"
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    if [[ -f /opt/ai-dock/etc/environment.sh ]]; then
        # shellcheck source=/dev/null
        source /opt/ai-dock/etc/environment.sh
    fi
    if [[ -f /opt/ai-dock/bin/venv-set.sh ]]; then
        # shellcheck source=/dev/null
        source /opt/ai-dock/bin/venv-set.sh comfyui
    elif [[ -f /venv/main/bin/activate ]]; then
        # shellcheck source=/dev/null
        source /venv/main/bin/activate
    fi
}

function comfy_root() {
    if [[ -d /opt/ComfyUI ]]; then
        echo /opt/ComfyUI
    elif [[ -d "${WORKSPACE}/ComfyUI" ]]; then
        echo "${WORKSPACE}/ComfyUI"
    else
        echo /opt/ComfyUI
    fi
}

function provisioning_update_comfyui() {
    local comfy
    comfy="$(comfy_root)"
    if [[ ! -d "${comfy}/.git" ]]; then
        printf "ComfyUI git checkout not found at %s — skip update\n" "${comfy}"
        return 0
    fi

    printf "Updating ComfyUI (MiniMax H3 needs 0.30.0+)\n"
    (
        cd "${comfy}"
        git fetch --tags origin || true
        if [[ -n "${COMFYUI_REF:-}" ]]; then
            git checkout -f "${COMFYUI_REF}" || true
            git pull --ff-only origin "${COMFYUI_REF}" || true
        else
            git checkout master 2>/dev/null || git checkout main || true
            git pull --ff-only || true
        fi
    )

    if [[ -f "${comfy}/requirements.txt" ]]; then
        pip_install -r "${comfy}/requirements.txt" || true
    fi
}

function link_model_dir() {
    local name="$1"
    local storage="${WORKSPACE}/storage/stable_diffusion/models/${name}"
    local comfy
    comfy="$(comfy_root)/models/${name}"

    mkdir -p "${storage}"
    mkdir -p "$(dirname "${comfy}")"

    if [[ -L "${comfy}" ]]; then
        return 0
    fi

    if [[ -d "${comfy}" ]]; then
        if [[ -n "$(ls -A "${comfy}" 2>/dev/null)" ]]; then
            mv "${comfy}"/* "${storage}/" 2>/dev/null || true
        fi
        rm -rf "${comfy}"
    fi

    ln -sfn "${storage}" "${comfy}"
}

function file_ready() {
    local path="$1"
    local min_bytes="$2"
    [[ -f "${path}" ]] || return 1
    local size
    size="$(stat -c%s "${path}" 2>/dev/null || stat -f%z "${path}")"
    [[ "${size}" -ge "${min_bytes}" ]]
}

function resolve_hf_cmd() {
    if command -v hf >/dev/null 2>&1; then
        echo "hf"
        return 0
    fi
    if command -v huggingface-cli >/dev/null 2>&1; then
        echo "huggingface-cli"
        return 0
    fi
    pip_install -U "huggingface_hub[cli]"
    if command -v hf >/dev/null 2>&1; then
        echo "hf"
        return 0
    fi
    if command -v huggingface-cli >/dev/null 2>&1; then
        echo "huggingface-cli"
        return 0
    fi
    return 1
}

function download_h3_models() {
    local models_root="${WORKSPACE}/storage/stable_diffusion/models"
    local missing=()
    local entry name rel min_bytes dest

    mkdir -p \
        "${models_root}/diffusion_models" \
        "${models_root}/text_encoders" \
        "${models_root}/vae"

    link_model_dir "diffusion_models"
    link_model_dir "text_encoders"
    link_model_dir "vae"

    for entry in "${H3_FILES[@]}"; do
        IFS='|' read -r name rel min_bytes <<< "${entry}"
        dest="${models_root}/${rel}"
        if file_ready "${dest}" "${min_bytes}"; then
            printf "Skip (already present): %s\n" "${name}"
        else
            if [[ -f "${dest}" ]]; then
                printf "Incomplete file, re-download: %s\n" "${name}"
                rm -f "${dest}"
            fi
            missing+=("${rel}")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        printf "All MiniMax H3 weights are already on disk\n"
        return 0
    fi

    if [[ -z "${HF_TOKEN:-}" ]]; then
        printf "WARNING: HF_TOKEN is empty. Accept the MiniMax H3 license on Hugging Face\n"
        printf "and set HF_TOKEN on the Vast instance if the download is gated.\n"
    fi

    local hf_cmd
    if ! hf_cmd="$(resolve_hf_cmd)"; then
        printf "ERROR: huggingface CLI is not available\n"
        return 1
    fi

    printf "Downloading %s file(s) from %s into %s\n" \
        "${#missing[@]}" "${HF_REPO}" "${models_root}"

    for rel in "${missing[@]}"; do
        printf "Downloading: %s\n" "${rel}"
        if [[ "${hf_cmd}" == "hf" ]]; then
            hf download "${HF_REPO}" "${rel}" --local-dir "${models_root}"
        else
            huggingface-cli download "${HF_REPO}" "${rel}" --local-dir "${models_root}"
        fi
    done

    local failed=0
    for entry in "${H3_FILES[@]}"; do
        IFS='|' read -r name rel min_bytes <<< "${entry}"
        dest="${models_root}/${rel}"
        if file_ready "${dest}" "${min_bytes}"; then
            printf "OK %s (%s bytes)\n" "${name}" "$(stat -c%s "${dest}" 2>/dev/null || stat -f%z "${dest}")"
        else
            printf "ERROR: missing or too small: %s\n" "${dest}"
            failed=1
        fi
    done

    return "${failed}"
}

function provisioning_start() {
    provisioning_activate_env
    provisioning_print_header
    provisioning_update_comfyui
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        pip_install "${PIP_PACKAGES[@]}" || true
    fi
    local dl_ok=0
    download_h3_models || dl_ok=1
    provisioning_print_end
    return "${dl_ok}"
}

provisioning_start
