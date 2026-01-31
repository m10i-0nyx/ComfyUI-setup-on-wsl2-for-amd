#!/bin/bash

export WORKSPACE="${WORKSPACE_PATH:-/workspace}"

# Python3.12(UV)仮想環境をセットアップ
curl -LsSf https://astral.sh/uv/install.sh | sh
. ${HOME}/.profile

rm -rf ${VENV_PATH} > /dev/null 2>&1
uv venv -p 3.12 ${VENV_PATH}
. ${VENV_PATH}/bin/activate

# PyTorch(ROCm版)をインストール
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2/torch-2.9.1%2Brocm7.2.0.lw.git7e1940d4-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2/torchvision-0.24.0%2Brocm7.2.0.gitb919bd0c-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2/triton-3.5.1%2Brocm7.2.0.gita272dfa8-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-7.2/torchaudio-2.9.0%2Brocm7.2.0.gite3c6ee2b-cp312-cp312-linux_x86_64.whl
uv pip3 uninstall torch torchvision triton torchaudio
uv pip3 install --break-system-packages torch-2.9.1+rocm7.2.0.lw.git7e1940d4-cp312-cp312-linux_x86_64.whl torchvision-0.24.0+rocm7.2.0.gitb919bd0c-cp312-cp312-linux_x86_64.whl torchaudio-2.9.0+rocm7.2.0.gite3c6ee2b-cp312-cp312-linux_x86_64.whl triton-3.5.1+rocm7.2.0.gita272dfa8-cp312-cp312-linux_x86_64.whl

TORCH_LOCATION=$(uv pip show torch | grep Location | awk -F ": " '{print $2}')
pushd ${TORCH_LOCATION}/torch/lib/
rm -f libhsa-runtime64.so*
popd

# ディレクトリを作成
mkdir -p ${WORKSPACE}/data/models/{checkpoints,clip_vision,configs,controlnet,diffusion_models,unet,hypernetworks,loras,text_encoders,upscale_models,vae,audio_encoders,model_patches,latent_upscale_models}

# ComfyUI をクローン,　依存関係をインストール
rm -rf ${COMFYUI_PATH} > /dev/null 2>&1
git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH}
cd ${COMFYUI_PATH}
export COMFYUI_TAG=$(git describe --tags --abbrev=0) # 最新のタグを取得
git checkout tags/${COMFYUI_TAG}
uv pip install -r requirements.txt
uv pip install -r manager_requirements.txt

# matrix-nio をインストール(ComfyUI-Manager 用)
uv pip install matrix-nio

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
<<<<<<< Updated upstream
export CLI_ARGS="--dont-print-server --force-fp16 "
=======
export CLI_ARGS="--dont-print-server --enable-manager"
>>>>>>> Stashed changes
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
