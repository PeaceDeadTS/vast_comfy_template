# Vast.ai: ComfyUI + MiniMax H3

Шаблон для быстрой аренды GPU на [Vast.ai](https://cloud.vast.ai/templates/) с последним ComfyUI и весами MiniMax H3 (T2V / I2V).

На Windows 10 достаточно этого репозитория. Docker Desktop и Linux на ПК не нужны: контейнер крутится на хосте Vast.

## Что качается при первом старте

Источник: [Comfy-Org/MiniMax-H3](https://huggingface.co/Comfy-Org/MiniMax-H3). В образ модели не входят.

- DiT: `minimax_h3_fl2va_bf16.safetensors` (~66.3 GB) → `models/diffusion_models/`
- Text encoder: `qwen3vl_32b_minimax_h3_int8_convrot.safetensors` (~25 GB) → `models/text_encoders/`
- Video VAE: `minimax_h3_video_vae_fp16.safetensors` (~4.9 GB) → `models/vae/`
- Audio VAE: `minimax_h3_audio_vae_fp32.safetensors` (~0.6 GB) → `models/vae/`

Итого ~97 GB. Повторный boot того же инстанса файлы не перекачивает.

Если полный BF16 не влезает в VRAM, в workflow вручную ставишь `minimax_h3_fl2va_int8_convrot.safetensors` (~34 GB). Скрипт его сам не качает.

R2V (`ref2va`) в этой версии не скачивается.

## Что нужно заранее

1. Аккаунт Vast.ai и баланс.
2. Этот репозиторий на GitHub (public — тогда raw-URL скрипта открывается без токена).
3. Hugging Face аккаунт, token (read) и принятая лицензия на странице модели.

## Как подключить к Vast

1. Репозиторий: https://github.com/PeaceDeadTS/vast_comfy_template
2. Raw-URL скрипта:

   `https://raw.githubusercontent.com/PeaceDeadTS/vast_comfy_template/main/provisioning/minimax-h3.sh`

3. На Vast: **Templates** → найти **ComfyUI** → **Edit**.
4. Заполнить поля из [TEMPLATE.md](TEMPLATE.md):
   - `PROVISIONING_SCRIPT` = raw-URL
   - `AUTO_UPDATE=true`
   - диск **200 GB**
   - фильтр `gpu_ram>=80 inet_down>=500 disk_space>=200`
5. **Create** (не Save чужого шаблона) — копия появится в **My Templates**.
6. При создании инстанса вписать `HF_TOKEN`. Не класть токен в публичный шаблон.
7. Дождаться provisioning, открыть Instance Portal → ComfyUI.
8. Template Library → Video → MiniMax H3 T2V / I2V.

Клик Download внутри ComfyUI качает файл на твой Windows, не на инстанс. Модели уже кладёт `provisioning/minimax-h3.sh`.

## GPU

Целевая карта: **RTX PRO 6000 Blackwell, 96 GB**. Полный BF16 DiT (~66 GB) + INT8 TE грузятся по очереди, в 96 GB это рабочий профиль. На 48 GB полный BF16 уйдёт в тяжёлый offload — тогда бери `fl2va_int8_convrot`.

## Файлы репозитория

- [`provisioning/minimax-h3.sh`](provisioning/minimax-h3.sh) — обновляет ComfyUI и качает 4 файла H3
- [`TEMPLATE.md`](TEMPLATE.md) — точные поля UI Vast
- [`.gitattributes`](.gitattributes) — LF для `*.sh`, чтобы Windows не сломал bash
