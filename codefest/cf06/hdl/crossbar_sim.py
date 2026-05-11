# =============================================================
# crossbar_sim.py
# Python simulation of the 4x4 Binary-Weight Crossbar MAC Unit
# ECE 410/510 — Codefest 6, CLLM Task
#
# Mirrors the SystemVerilog crossbar_mac.sv behavior exactly.
# Prof spec: out[j] = Σ_i weight[i][j] × in[i]
# Weights: +1 (stored as 1) or −1 (stored as 0) in 4×4 array.
# Inputs: 8-bit signed. Outputs: 11-bit signed accumulator.
# =============================================================

def decode_weights(weight_in_bits):
    """
    Decode 16-bit integer into 4x4 weight matrix.
    Bit [i*4+j] = 1 → W[i][j] = +1
    Bit [i*4+j] = 0 → W[i][j] = -1
    """
    W = [[0]*4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            W[i][j] = +1 if (weight_in_bits >> (i*4+j)) & 1 else -1
    return W

def crossbar_mac(W, inputs):
    """
    Compute out[j] = sum_i W[i][j] * inputs[i]
    Matches the registered (1-cycle latency) SV module output.
    """
    outputs = []
    for j in range(4):
        acc = sum(W[i][j] * inputs[i] for i in range(4))
        outputs.append(acc)
    return outputs

def print_weight_matrix(W):
    print("  Weight matrix W[i][j]:")
    print("         col0  col1  col2  col3")
    for i in range(4):
        print(f"  row{i}:  {W[i]}")

def run_simulation():
    print("=" * 55)
    print(" crossbar_sim.py — 4x4 Binary-Weight Crossbar MAC")
    print(" ECE 410/510  Codefest 6")
    print("=" * 55)

    # ----------------------------------------------------------
    # Prof-specified weights (Task 5 exact)
    # W = [[1,−1,1,−1],[1,1,−1,−1],[−1,1,1,−1],[−1,−1,−1,1]]
    # Encoded: bit[i*4+j]=1 if W[i][j]=+1, else 0
    #   Row0 [1,-1,1,-1]  → bits[3:0]  = 0b0101
    #   Row1 [1,1,-1,-1]  → bits[7:4]  = 0b0011
    #   Row2 [-1,1,1,-1]  → bits[11:8] = 0b0110
    #   Row3 [-1,-1,-1,1] → bits[15:12]= 0b1000
    # ----------------------------------------------------------
    PROF_WEIGHTS = 0b1000_0110_0011_0101   # = 0x8635

    W = decode_weights(PROF_WEIGHTS)
    inputs = [10, 20, 30, 40]

    print(f"\n[SIM 1] Prof-specified test (Task 5)")
    print(f"  weight_in = 0x{PROF_WEIGHTS:04X} = 0b{PROF_WEIGHTS:016b}")
    print_weight_matrix(W)
    print(f"  inputs    = {inputs}")

    print(f"\n  Hand-calculated (out[j] = Σ_i W[i][j]·in[i]):")
    outputs = crossbar_mac(W, inputs)
    for j in range(4):
        terms = " + ".join(f"({W[i][j]:+d})×{inputs[i]}" for i in range(4))
        print(f"    out[{j}] = {terms} = {outputs[j]}")

    expected = [-40, 0, -20, -20]
    match = outputs == expected
    print(f"\n  Result:   {outputs}")
    print(f"  Expected: {expected}")
    print(f"  {'✓ MATCH' if match else '✗ MISMATCH'}")

    # ----------------------------------------------------------
    # Additional verification cases
    # ----------------------------------------------------------
    print(f"\n{'─'*55}")
    print(f"[SIM 2] Sanity checks")

    cases = [
        (0xFFFF, [1,1,1,1],        [4,4,4,4],        "all +1 weights, in=[1,1,1,1]"),
        (0x0000, [1,1,1,1],        [-4,-4,-4,-4],    "all -1 weights, in=[1,1,1,1]"),
        (0xFFFF, [127,127,127,127],[508,508,508,508], "max+ inputs"),
        (0x0000, [-128,-128,-128,-128],[512,512,512,512],"min inputs, -1 weights→+512"),
        (PROF_WEIGHTS, [0,0,0,0],  [0,0,0,0],        "zero input"),
    ]

    all_pass = True
    for (w_val, inp, exp, desc) in cases:
        W2 = decode_weights(w_val)
        got = crossbar_mac(W2, inp)
        ok = got == exp
        if not ok: all_pass = False
        print(f"  {'PASS' if ok else 'FAIL'} {desc}")
        if not ok:
            print(f"       expected {exp}, got {got}")

    print(f"\n{'=' * 55}")
    print(f" SUMMARY: Prof test {'PASSED' if match else 'FAILED'}, "
          f"sanity checks {'ALL PASSED' if all_pass else 'SOME FAILED'}")
    if match and all_pass:
        print(" Ready to compare against SystemVerilog simulation log.")
    print(f"{'=' * 55}")

if __name__ == "__main__":
    run_simulation()
