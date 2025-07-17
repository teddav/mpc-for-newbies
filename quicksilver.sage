# This is an example of QuickSilver on a simple boolean circuit
# Check the article for a detailed explanation
# Here's the circuit in Bristol format:
# 4 8
# 2 2 2
# 1 2

# 2 1 0 2 4 AND
# 2 1 1 3 5 XOR
# 2 1 1 5 6 AND
# 2 1 2 4 7 XOR

# Wires are bits, so we use GF(2)
F2 = GF(2)
R.<x> = PolynomialRing(F2)

# We use a field extension of GF(2) to handle the other parameters of the VOLE
# For the extension, we use an irreducible polynomial of degree 128 (this is a random polynomial for this example)
# It was chosen with this script:
# while True:
#     Q = R.random_element(degree=128)
#     if Q.is_irreducible():
#         print(Q)
#         break
Q = x^128 + x^126 + x^123 + x^121 + x^120 + x^118 + x^114 + x^112 + x^107 + x^105 + x^104 + x^103 + x^99 + x^97 + x^94 + x^89 + x^88 + x^81 + x^80 + x^78 + x^73 + x^71 + x^70 + x^68 + x^67 + x^66 + x^61 + x^58 + x^55 + x^54 + x^53 + x^52 + x^51 + x^50 + x^49 + x^48 + x^46 + x^45 + x^43 + x^42 + x^40 + x^39 + x^34 + x^32 + x^31 + x^29 + x^26 + x^25 + x^24 + x^22 + x^20 + x^18 + x^14 + x^12 + x^11 + x^6 + x^5 + x^4 + 1
F128.<x> = F2.extension(Q)

# We normally use VOLE and generate the shares based on the wires of the entire circuit
# But I'm going to use OLE for this example, 1 for each wire
# I think it will make it easier to understand the protocol

# We'll treat OLE as a black box here
# Let's define a function for OLE that returns the shares of the wire
def OLE(w, delta):
    k = F128.random_element()
    m = k - w * delta
    return (k, m)

# Verifier generates DELTA, used during the entire protocol
delta = F128.random_element()

# Prover generates the values for each wire
# The input wires (w0 to w3) are chosen randomly here
w0 = F2.random_element()
w1 = F2.random_element()
w2 = F2.random_element()
w3 = F2.random_element()

# The rest of the wires (w4 to w7) are computed from the input wires, based on the circuit definition
w4 = w0 * w2
w5 = w1 + w3
w6 = w1 * w5
w7 = w2 + w4

# Prover commits to all necessary wires
# - inputs
(k0, m0) = OLE(w0, delta)
(k1, m1) = OLE(w1, delta)
(k2, m2) = OLE(w2, delta)
(k3, m3) = OLE(w3, delta)
# - results of AND (MUL) gates
(k4, m4) = OLE(w4, delta)
(k6, m6) = OLE(w6, delta)

# ADD (XOR) gates are automatically computed because they are additively homomorphic
k7 = k2 + k4
m7 = m2 + m4
assert k7 == m7 + w7 * delta
k5 = k1 + k3
m5 = m1 + m3
assert k5 == m5 + w5 * delta


# MUL gates are not multiplicatively homomorphic
# For the first gate, this is what we want to check:
assert k0 * k2 == (m0 * m2) + (m0 * w2 + m2 * w0) * delta + (w0 * w2) * delta**2

# In the article, we described how to check each gate individually
# the Verifier computes his part for each gate: `input1 * input2 - output * delta`
K1 = k0 * k2 - k4 * delta
K2 = k1 * k5 - k6 * delta

# the Prover computes his part:
# (again, if you don't remember why, check the article)
# and sends his shares to the Verifier
M1 = m0 * m2
W1 = m0 * w2 + m2 * w0 - m4
M2 = m1 * m5
W2 = m1 * w5 + m5 * w1 - m6

# Verifier can verify that the result is correct
assert K1 == M1 + W1 * delta
assert K2 == M2 + W2 * delta

# if this passes, the Verifier can be sure that the gates are correct
print("Gates are correct")


# But we can do better. Instead of checking gates individually, we can batch them.
print("But... let's batch them")

# Verifier generates a random value `chi`
chi = F128.random_element()

# Verifier computes his part:
K = K1 * chi + K2 * chi**2

# Prover computes his part:
M = M1 * chi + M2 * chi**2
W = W1 * chi + W2 * chi**2

# Verifier can check all gates at once
assert K == M + W * delta
print("Batched gates are still correct")

# ZERO-KNOWLEDGE
# But... the prover would need to send M and W to the verifier, which could leak the inputs
# So we need to hide the inputs
# Prover needs to generate a random value to hide the inputs
r_w = F128.random_element()
(r_k, r_m) = OLE(r_w, delta)

M_rand = r_m - M
W_rand = r_w - W
K_rand = r_k - K

# This is what the Verifier will finally check
assert K_rand == M_rand + W_rand * delta
print("Zero-knowledge is preserved")