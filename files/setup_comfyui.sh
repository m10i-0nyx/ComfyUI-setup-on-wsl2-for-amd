#!/bin/bash

# Python3.13(UV)仮想環境をセットアップ
curl -LsSf https://astral.sh/uv/install.sh | sh
. ${HOME}/.profile

rm -rf ${VENV_PATH} > /dev/null 2>&1
uv venv -p 3.13 ${VENV_PATH}
. ${VENV_PATH}/bin/activate

# PyTorch(ROCm版)をインストール
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4

# ディレクトリを作成
mkdir -p /workspace/data/models/{checkpoints,clip_vision,controlnet,diffusion_models,gligen,hypernetworks,loras,text_encoders,upscale,vae}

# ComfyUI をクローン,　依存関係をインストール
rm -rf ${COMFYUI_PATH} > /dev/null 2>&1
git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH}
cd ${COMFYUI_PATH}
export COMFYUI_TAG=$(git describe --tags --abbrev=0) # 最新のタグを取得
git checkout tags/${COMFYUI_TAG}
sed -i '/^pynvml=?.*$/d' requirements.txt
uv pip install -r requirements.txt

# ComfyUI-Manager をクローン,　依存関係をインストール
cd ${COMFYUI_PATH}/custom_nodes
git clone -b main --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git ComfyUI-Manager
cd ComfyUI-Manager
sed -i '/^pynvml=?.*$/d' requirements.txt
uv pip install -r requirements.txt

# Crystools ノードをインストール
cd ${COMFYUI_PATH}/custom_nodes
git clone https://github.com/crystian/comfyui-crystools.git comfyui-crystools
cd comfyui-crystools
sed -i '/^pynvml=?.*$/d' requirements.txt
uv pip install -r requirements.txt

cat << '_EOL_' > /workspace/comfyui/extra_model_paths.yaml
---
a111:
  base_path: /workspace
  checkpoints: data/models/checkpoints
  clip_vision: data/models/clip_vision
  controlnet: data/models/controlnet
  custom_nodes: /workspace/comfyui/custom_nodes
  diffusion_models: data/models/diffusion_models
  embeddings: data/embeddings
  gligen: data/models/gligen
  hypernetworks: data/models/hypernetworks
  loras: data/models/loras
  text_encoders: data/models/text_encoders
  upscale_models: data/models/upscale_models
  vae: data/models/vae
_EOL_

# ComfyUI 起動スクリプトを作成
cat << '_EOL_' > ${COMFYUI_PATH}/start_comfyui.sh
#!/bin/bash
. ${HOME}/.profile
. ${VENV_PATH}/bin/activate
cd ${COMFYUI_PATH}
export CLI_ARGS="--use-pytorch-cross-attention --dont-print-server --force-fp16 "
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
