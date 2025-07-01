import torch
import numpy as np
import math
import os
from transformers import AutoTokenizer, AutoModel

MODEL_NAME = "distilbert-base-uncased"
SEQ_LEN = 512
OUTPUT_DIR = f"workload_different_sizes/real_qkv_core_test_data_layer0_{SEQ_LEN}"
SEED = 42
TARGET_LAYER_INDEX = 0

torch.manual_seed(SEED)
np.random.seed(SEED)

def save_matrix_to_file(matrix, filename):
    """Saves a NumPy matrix or vector to a file."""
    if matrix.ndim == 1:
        matrix = matrix.reshape(1, -1)
    elif matrix.ndim == 0:
         matrix = matrix.reshape(1, 1)
    matrix = matrix.astype(np.float32)
    rows, cols = matrix.shape
    with open(filename, "w") as f:
        f.write(f"{rows} {cols}\n")
        for row in matrix:
            f.write(" ".join([f"{num:.8f}" for num in row]) + "\n")


if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"Loading tokenizer and model: {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModel.from_pretrained(MODEL_NAME)
    model.eval()

    config = model.config
    d_model = config.dim 
    n_heads = config.n_heads
    head_dim = d_model // n_heads
    print(f"Model Config: d_model={d_model}, n_heads={n_heads}, head_dim={head_dim}")

    input_text = "This is an example sentence to test the self-attention mechanism."
    print(f"Input text: \"{input_text}\"")
    inputs = tokenizer(input_text, return_tensors='pt', max_length=SEQ_LEN, padding='max_length', truncation=True)
    input_ids = inputs['input_ids']
    attention_mask = inputs['attention_mask']


    extended_attention_mask = attention_mask.unsqueeze(1).unsqueeze(2) 
    extended_attention_mask = extended_attention_mask.to(dtype=next(model.parameters()).dtype) 
    additive_attention_mask = (1.0 - extended_attention_mask) * torch.finfo(extended_attention_mask.dtype).min


    with torch.no_grad():
        embedding_output = model.embeddings(input_ids=input_ids)
        hidden_state_input_to_layer = embedding_output 

    print(f"Accessing projection layers from Layer {TARGET_LAYER_INDEX} Attention...")
    try:
        attention_layer = model.transformer.layer[TARGET_LAYER_INDEX].attention
        q_lin = attention_layer.q_lin
        k_lin = attention_layer.k_lin
        v_lin = attention_layer.v_lin
    except AttributeError:
        print(f"Error accessing layers for {MODEL_NAME}. Print model structure to check.")
        exit()

    print("Performing manual projection and head splitting...")
    with torch.no_grad():
        q_proj = q_lin(hidden_state_input_to_layer) 
        k_proj = k_lin(hidden_state_input_to_layer) 
        v_proj = v_lin(hidden_state_input_to_layer) 

        batch_size = q_proj.shape[0]

        def split_heads(tensor, num_heads, head_dim):
             """Splits dim into num_heads x head_dim and permutes."""
             new_shape = tensor.size()[:-1] + (num_heads, head_dim)
             tensor = tensor.view(new_shape)
             return tensor.permute(0, 2, 1, 3)

        q_heads = split_heads(q_proj, n_heads, head_dim) 
        k_heads = split_heads(k_proj, n_heads, head_dim) 
        v_heads = split_heads(v_proj, n_heads, head_dim)

    print("Calculating reference core attention output per head...")
    with torch.no_grad():
        k_heads_t = k_heads.transpose(-1, -2)

        attention_scores = torch.matmul(q_heads, k_heads_t) / math.sqrt(head_dim)

        attention_probs = torch.nn.functional.softmax(attention_scores, dim=-1)

        expected_context_heads = torch.matmul(attention_probs, v_heads)

    print(f"Saving Q, K, V, and expected context per head for {n_heads} heads...")
    q_heads_np = q_heads.squeeze(0).cpu().numpy()
    k_heads_np = k_heads.squeeze(0).cpu().numpy()
    v_heads_np = v_heads.squeeze(0).cpu().numpy()
    expected_context_heads_np = expected_context_heads.squeeze(0).cpu().numpy()
    for i in range(n_heads):
        head_dir = os.path.join(OUTPUT_DIR, f"head_{i:02d}")
        os.makedirs(head_dir, exist_ok=True)

        save_matrix_to_file(q_heads_np[i], os.path.join(head_dir, "q_matrix.txt"))
        save_matrix_to_file(k_heads_np[i], os.path.join(head_dir, "k_matrix.txt"))
        save_matrix_to_file(v_heads_np[i], os.path.join(head_dir, "v_matrix.txt"))
        save_matrix_to_file(expected_context_heads_np[i], os.path.join(head_dir, "expected_context.txt"))

    print("\nData generation complete.")
    print(f"Files saved in: {OUTPUT_DIR}")
    print(f"Model Config: d_model={d_model}, n_heads={n_heads}, head_dim={head_dim}, target_layer={TARGET_LAYER_INDEX}")