# IKNP OT Extension Protocol for semi-honest receiver
# https://eprint.iacr.org/2003/196.pdf
# The goal is to use the results of base OTs to compute m OT of l-bits strings.
# It will allow to reduce the m OT of l-bits strings to k OT of m-bits strings
# with m > k >= l.
# Note:
# - addition in GF(2) is equivalent to XOR.
# - set_immutable() is a SageMath method to make vector immutables to hash it

import os

# Simple XOR encryption
def encrypt(m, k):
    m_int = int.from_bytes(m, 'big')
    return m_int ^^ k

def decrypt(c, k):
    m_int = c ^^ k
    byte_length = max(1, (m_int.bit_length() + 7) // 8)
    return m_int.to_bytes(byte_length, 'big')

# IKNP Protocol Parameters
F2 = GF(2)
k = 16   # Number of base OTs (security parameter)
m = 32   # Number of extended OTs
l = 32   # Message length in bits

### Step 0: Inputs of the protocol ###

# Sender inputs: m pairs of messages of length l bits
inputs = [(os.urandom(l), os.urandom(l)) for _ in range(m)]
# Receiver choice vector: vector of length m
r = vector([F2.random_element() for _ in range(m)])

### Step 1: Base OT with roles reversed ###

# Sender initialization
# Generate random choice vector s of length k
s = vector([F2.random_element() for _ in range(k)])
# Receiver initialization
# Create random matrix T of size m × k (m rows, k columns)
T = matrix(F2, [[F2.random_element() for _ in range(k)] for _ in range(m)])
# Receiver construct its inputs such as k pairs of vectors of length m (ti, ti ⊕ r) for each column i
receiver_inputs = [(T.column(i), T.column(i) + r) for i in range(k)]

# Base OT simulation with roles reversed
# Sender acts as the receiver and Receiver acts as the sender
# The base OT is not fixed by the IKNP protocol, it can be chou-orlandi or other 1-out-of-2 OT
# At the end, the Sender will receive k vectors of length m
# He can construct a matrix Q of size m * k with the relation qi = (s[i] * r) ⊕ ti for any column i
# or qi = (s * r[i]) ⊕ ti for any row i
Q = []
for i, choice in enumerate(s):
    received = receiver_inputs[i][choice] # either column ti or ti ⊕ r
    Q.append(received)
# loop is equivalent to Q = [(s[i] * r) + T.column(i) for i in range(k)]
# The matrix was constructed by columns but the protocol works on the rows
# so we need to transpose it
Q = matrix(Q).transpose()

### Step 2:  Extension ###
# Sender and receiver can now use the results of the k base OT in step 1 to compute m OT
# by leveraging Q and the relation established between Q, s, r and T
# We iterate over the m pairs of messages and choices from the initial inputs of the protocol
received_messages = []
for j in range(m):
    # Sender computes two keys for the j-th OT
    row_j = Q.row(j)
    # Key for message 0: H(j, q_j)
    # Key for message 1: H(j, q_j ⊕ s)
    k0 = hash(row_j.set_immutable())
    k1 = hash((row_j + s).set_immutable())

    # Sender encrypts the messages with the keys
    # and sends them to the receiver
    msg0 = inputs[j][0]
    msg1 = inputs[j][1]
    e0 = encrypt(msg0, k0)
    e1 = encrypt(msg1, k1)

    # Receiver computes their decryption key
    t_j = T.row(j)
    kr = hash(t_j.set_immutable())
    # Receiver decrypts the corresponding message based on his choice
    choice = int(r[j])
    decrypted_message = decrypt(e0, kr) if choice == 0 else decrypt(e1, kr)

    assert decrypted_message == inputs[j][choice]
print("Success")

# All of this works due to how the symmetric keys are computed.
# Consider the row j:
# The key for message 0 is k0 = H(j, q_j)
# The key for message 1 is k1 = H(j, q_j ⊕ s)
# The key for the receiver is kr = H(j, t_j)
# But from the relation established in step 1, we have q_j = (s * r[j]) ⊕ t_j
# By substituting q_j in the sender's keys, we get:
# if r[j] == 0:
#     k0 = H(j, (s * 0) ⊕ t_j) = H(j, t_j)
#     k1 = H(j, (s * 0) ⊕ t_j ⊕ s) = H(j, t_j ⊕ s)
#     Receiver can decrypt the message 0 as k0 = kr
# if r[j] == 1:
#     k0 = H(j, (s * 1) ⊕ t_j) = H(j, t_j ⊕ s)
#     k1 = H(j, (s * 1) ⊕ t_j ⊕ s) = H(j, t_j)
#     Receiver can decrypt the message 1 as k1 = kr
# Hence the receiver can always decrypt the message based on his choice r
