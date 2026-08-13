# Поля шаблона Vast.ai (ComfyUI + MiniMax H3)

Не собираем свой Docker-образ. Берём готовый recommended-шаблон **ComfyUI**, жмём **Edit**, меняем поля ниже, затем **Create** (копия попадёт в My Templates).

## Image

Не трогать. Оставить образ готового шаблона ComfyUI (линейка `ai-dock/comfyui`).

## Environment Variables

Добавить или заменить:

| Имя | Значение | Комментарий |
|---|---|---|
| `PROVISIONING_SCRIPT` | `https://raw.githubusercontent.com/PeaceDeadTS/vast_comfy_template/main/provisioning/minimax-h3.sh` | Raw-URL скрипта из этого репо |
| `AUTO_UPDATE` | `true` | Подтянуть свежий ComfyUI (H3 с 0.30.0+) |
| `COMFYUI_ARGS` | `--disable-auto-launch --port 18188 --enable-cors-header` | Как в официальном шаблоне, не менять без нужды |
| `WEB_ENABLE_AUTH` | `true` | Не выключать на публичном IP |
| `HF_TOKEN` | *(пусто в шаблоне)* | Вписать **только при создании инстанса**, не в публичный шаблон |

`HF_TOKEN` — Hugging Face token с правом read. Перед первым запуском на https://huggingface.co/Comfy-Org/MiniMax-H3 принять community license.

## Диск

- **Disk space: 200 GB**
- Модели ~97 GB + ComfyUI + вывод + запас

## Фильтр офферов (Search / Create)

Вставить в фильтр поиска машин:

```
gpu_ram>=80 inet_down>=500 disk_space>=200
```

Целевая карта: RTX PRO 6000 Blackwell (96 GB). На 48 GB полный BF16 DiT не держать — fallback `minimax_h3_fl2va_int8_convrot.safetensors`.

## Порты

Не трогать порты готового шаблона. ComfyUI в этом образе слушает **18188**, доступ через Instance Portal.

## После Create

1. Выбрать шаблон в **My Templates**.
2. Снять инстанс с хорошим uplink (`inet_down>=500`).
3. В форме инстанса добавить `HF_TOKEN`.
4. Дождаться конца provisioning (десятки минут, качается ~97 GB). Логи: Jupyter terminal или `/var/log` / supervisor.
5. Instance Portal → **OPEN** → ComfyUI.
6. Template Library → Video → **MiniMax H3 T2V** или **I2V**. Кнопки Download в UI не нажимать — файлы уже на диске инстанса.

## Проверка на инстансе

```bash
ls -lh /workspace/storage/stable_diffusion/models/diffusion_models/minimax_h3_fl2va_bf16.safetensors
ls -lh /workspace/storage/stable_diffusion/models/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors
ls -lh /workspace/storage/stable_diffusion/models/vae/minimax_h3_video_vae_fp16.safetensors
ls -lh /workspace/storage/stable_diffusion/models/vae/minimax_h3_audio_vae_fp32.safetensors
```

Ожидаемые размеры: ~66.3 GB, ~25 GB, ~4.9 GB, ~0.6 GB.

## Чего не делать

- Не публиковать шаблон с заполненным `HF_TOKEN`.
- Не качать модели в Docker-образ.
- Не ставить диск меньше 180 GB.
