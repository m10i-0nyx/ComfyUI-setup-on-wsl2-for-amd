#!/bin/bash

export WORKSPACE="${WORKSPACE_PATH:-/workspace}"

# Python3.12(UV)仮想環境をセットアップ
curl -LsSf https://astral.sh/uv/install.sh | sh
. ${HOME}/.profile

rm -rf ${VENV_PATH} > /dev/null 2>&1
uv venv -p 3.12 ${VENV_PATH}
. ${VENV_PATH}/bin/activate

# PyTorch(ROCm版)をインストール
#uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4

# PyTorch(ROCm版)をインストール (2025/12/27: AMD公式の ROCm 6.4.4 + PyTorch 2.8.0 + Python 3.12 を直接ダウンロードしてインストール)
cd ~
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.4/pytorch_triton_rocm-3.4.0%2Brocm6.4.4.gitf9e5bf54-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.4/torch-2.8.0%2Brocm6.4.4.gitc1404424-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.4/torchvision-0.23.0%2Brocm6.4.4.git824e8c87-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.4/torchaudio-2.8.0%2Brocm6.4.4.git6e1c7fe9-cp312-cp312-linux_x86_64.whl
uv pip install *.whl
rm -f *.whl

# Workaround(2025/12/27): libhsa-runtime64.so 関連のエラーを回避
python3 -c "import torch; print('Workaround Before:', 'torch.cuda.is_available() = ', torch.cuda.is_available())"
TORCH_LOCATION=$(uv pip show torch | grep Location | awk -F ": " '{print $2}')
cd ${TORCH_LOCATION}/torch/lib/
rm -f libhsa-runtime64.so*
python3 -c "import torch; print('Workaround After:', 'torch.cuda.is_available() = ', torch.cuda.is_available())"

# ComfyUI をクローン,　依存関係をインストール
rm -rf ${COMFYUI_PATH} > /dev/null 2>&1
git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH}
cd ${COMFYUI_PATH}
export COMFYUI_TAG=$(git describe --tags --abbrev=0) # 最新のタグを取得
git checkout tags/${COMFYUI_TAG}
uv pip install -r requirements.txt

# ComfyUI-Manager をクローン,　依存関係をインストール
cd ${COMFYUI_PATH}/custom_nodes
git clone -b main --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git comfyui-manager
cd comfyui-manager
uv pip install -r requirements.txt

# Crystools ノードをインストール
# AMD ROCm 環境では動作しないためコメントアウト
#cd ${COMFYUI_PATH}/custom_nodes
#git clone https://github.com/crystian/comfyui-crystools.git comfyui-crystools
#cd comfyui-crystools
#uv pip install -r requirements.txt

cat << _EOL_ > ${WORKSPACE_PATH}/comfyui/extra_model_paths.yaml
comfyui:
    base_path: ${WORKSPACE_PATH}/data/
    custom_nodes: ${COMFYUI_PATH}/custom_nodes/
    checkpoints: models/checkpoints/
    text_encoders: |
        models/text_encoders/
        models/clip/
    clip_vision: models/clip_vision/
    configs: models/configs/
    controlnet: models/controlnet/
    diffusion_models: |
        models/diffusion_models/
        models/unet/
    embeddings: models/embeddings/
    loras: models/loras/
    upscale_models: models/upscale_models/
    vae: models/vae/
    audio_encoders: models/audio_encoders/
    model_patches: models/model_patches/
_EOL_

# ComfyUI 起動スクリプトを作成
cat << '_EOL_' > ${COMFYUI_PATH}/start_comfyui.sh
#!/bin/bash
source ${HOME}/.profile
source ${VENV_PATH}/bin/activate

# Make sure model directories exist
mkdir -p ${WORKSPACE_PATH}/data/models/{checkpoints,clip_vision,configs,controlnet,diffusion_models,unet,hypernetworks,loras,text_encoders,upscale_models,vae,audio_encoders,model_patches}

echo "===== AMD ROCm info ====="
rocminfo
echo "===== ComfyUI Entrypoint Info ====="
echo "Workspace: ${WORKSPACE_PATH}"
echo "Venv: ${VENV_PATH}"
echo "Python: $(which python) ($(python --version))"
echo "===== torch info ====="
python -c "import torch; print('torch=', torch.__version__); print('avail=', torch.cuda.is_available())"
echo "==================================="

cd ${COMFYUI_PATH}
export CLI_ARGS="--dont-print-server --force-fp16 "
python3 -u main.py --listen --port 8188 ${CLI_ARGS}
_EOL_

chmod +x ${COMFYUI_PATH}/start_comfyui.sh

# ComfyUI 停止スクリプトを作成
cat << '_EOL_' > ${COMFYUI_PATH}/stop_comfyui.sh
#!/bin/bash
pkill -f "python3 -u main.py"
_EOL_

chmod +x ${COMFYUI_PATH}/stop_comfyui.sh

echo "ComfyUI setup completed."

echo "Waiting for 5 seconds to ensure all processes are settled..."
sleep 5
