#!/bin/bash

EXP_NAME='trial1'
IMAGE_NAME='DSC00580'
IMAGE_EXT='jpg'
TRAJ='chair_above'
TRAJ_DESCRIPTION="Reach the chair in the corner of the room by flying over the table making sure not to collide with the table or the chairs in the middle of the scene. You should keep the target chair always in frame and stop when the target chair is the center of the view."

# Initial setup
echo SETTING UP EXPERIMENT
mkdir -p CUT3R/my_examples/${EXP_NAME}
mkdir -p results/${EXP_NAME}/step00
touch results/${EXP_NAME}/${TRAJ}.txt
cp images/${IMAGE_NAME}.${IMAGE_EXT} CUT3R/my_examples/${EXP_NAME}/frame_000.png
cp images/${IMAGE_NAME}.${IMAGE_EXT} results/${EXP_NAME}/step00/rgb.png

cd CUT3R

module load Anaconda2/2019.10-fasrc01 cuda/11.8
source activate /n/home08/adimitriou0/miniconda/envs/cut3r

python --version

echo RUNNING CUT3R

# Initial CUT3R inference
python demo.py \
    --model_path src/cut3r_512_dpt_4_64.pth \
    --seq_path my_examples/${EXP_NAME} \
    --device cuda \
    --size 512 \
    --vis_threshold 1.5 \
    --output_dir ./output/${EXP_NAME} \
    --exp_name ${EXP_NAME}


cd ../

# Initial GPT prompt
python gpt_prompter.py \
    --traj_desc "${TRAJ_DESCRIPTION}" \
    --exp_name ${EXP_NAME} \
    --traj_file results/${EXP_NAME}/${TRAJ}.txt

conda deactivate

# Start loop
for i in $(seq 1 3); do
    echo "========== ITERATION $i =========="

    cd ViewCrafter
    echo "LOADING MODULES"

    echo "ACTIVATING ENVIRONMENT"
    source activate /n/home08/adimitriou0/miniconda/envs/viewcrafter

    echo "RUNNING VIEWCRAFTER"
    python inference.py \
        --image_dir my_images/${IMAGE_NAME}.${IMAGE_EXT} \
        --out_dir ./output \
        --traj_txt ../results/${EXP_NAME}/${TRAJ}.txt \
        --mode single_view_txt_free \
        --exp_id ${EXP_NAME} \
        --seed 123 \
        --ckpt_path ./checkpoints/model.ckpt \
        --config configs/inference_pvd_1024.yaml \
        --ddim_steps 50 \
        --device cuda:0 \
        --height 576 \
        --width 1024 \
        --model_path ./checkpoints/DUSt3R_ViTLarge_BaseDecoder_512_dpt.pth

    conda deactivate

    cd ../CUT3R
    echo "ACTIVATING ENVIRONMENT"
    source activate /n/home08/adimitriou0/miniconda/envs/cut3r

    echo "RUNNING CUT3R"
    python demo.py \
        --model_path src/cut3r_512_dpt_4_64.pth \
        --seq_path my_examples/${EXP_NAME} \
        --device cuda \
        --size 512 \
        --vis_threshold 1.5 \
        --output_dir ./output/${EXP_NAME} \
        --exp_name ${EXP_NAME}

    cd ../
    echo "PROMPTING GPT"
    python gpt_prompter.py \
        --traj_desc "${TRAJ_DESCRIPTION}" \
        --exp_name ${EXP_NAME} \
        --traj_file results/${EXP_NAME}/${TRAJ}.txt

    conda deactivate
done

echo "===== DONE WITH ALL ITERATIONS ====="

