# MIT License
#
# Copyright (c) 2026 Christopher Gilliard
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ──────────────────────────────────────────────────────────────────────────────
# file: compress.S - compression program
# ──────────────────────────────────────────────────────────────────────────────

_start:
	j		main

main:
	li		a0, 'x'
	jal		write_byte
	li		a0, '\n'
	jal		write_byte
	j		exit

print_hex:
	SETUP		s0, s1, s2

	mv		s0, a0			# Save original value
	li		s2, 0			# flag = 0 (skipping leading)

	# Print "0x" prefix 
	li		a0, '0' 
	jal		write_byte
	li		a0, 'x'
	jal		write_byte

	# Special Case: If value is 0, just print '0' and exit
	bnez		s0, 1f
	li		a0, '0'
	jal		write_byte
	j		4f

1:	li		s1, 60			# Start at highest nibble
2:	
	srl		t2, s0, s1		# Isolate nibble
	andi		t2, t2, 0xF

	# Skip leading zeros logic
	bnez		t2, 3f			# If nibble != 0, start
	bnez		s2, 3f			# If already started, print
	j		next_nibble		# Otherwise, skip

3:	li		s2, 1			# Flip "started" flag

	# Convert nibble to ASCII
	li		a0, 10
	blt		t2, a0, 5f		# If 0-9
	addi		t2, t2, 7		# Adjust for A-F
5:	addi		a0, t2, 48		# ASCII '0'
	jal		write_byte

next_nibble:
	addi		s1, s1, -4		# Move to next 4 bits
	bgez		s1, 2b

4:	RETURN

print_str:
	li		t3, UART_BASE		# UART Base
	mv		t1, a0			# mv arg to temp
1:	lbu		t0, 0(t1)		# read nth item
	beqz		t0, 2f			# null terminate
	lbu		t2, UART_LSR(t3)	# check status
	andi		t2, t2, UART_WR_MASK	# mask
	beqz		t2, 1b			# retry
	sb		t0, UART_RBR(t3)	# send to UART
	addi		t1, t1, 1		# Next char
	j		1b			# Loop back
2:	ret


print_dec:
	SETUP		s0, s1, s2
	addi		sp, sp, -32

	mv		s0, a0
	li		s1, 10
	li		s2, 0
	
	# 1. Handle Negative
	bgez		s0, 1f
	li		a0, '-'
	jal		write_byte
	neg		s0, s0
	
1:	# 2. Special Case: Zero
	bnez		s0, 2f
	li		a0, '0'
	jal		write_byte
	j		4f
	
2:	# 3. Generate Digits (Store at offset 32+)
	remu		t0, s0, s1
	divu		s0, s0, s1
	addi		t0, t0, 48		# Convert to ASCII

	mv		t1, sp			# Buffer start
	add		t1, t1, s2		# Buffer + index
	sb		t0, 0(t1)

	addi		s2, s2, 1
	bnez		s0, 2b

3:	# 4. Print Digits (Reverse)
	addi		s2, s2, -1
	mv		t1, sp
	add		t1, t1, s2
	lbu		a0, 0(t1)
	jal		write_byte
	bnez		s2, 3b

4:
	addi		sp, sp, 32
	RETURN


read_byte:
	li		t0, UART_BASE		# UART Base
1:	lbu		t1, UART_LSR(t0)	# Read from UART
	andi		t1, t1, UART_RD_MASK	# mask
	beqz		t1, 1b			# if not ready read again
	lbu		a0, UART_RBR(t0)	# Get current char, store a0
	ret

write_byte:
	li		t0, UART_BASE		# UART Base
1:	lbu		t1, UART_LSR(t0)	# load state
	andi		t1, t1, UART_WR_MASK	# mask
	beqz		t1, 1b			# retry
	sb		a0, UART_RBR(t0)	# send to UART
	ret

exit:
	li		t0, EXIT_ADDR		# load exit addr
	li		t1, EXIT_PASS		# shutdown command
	sw		t1, UART_RBR(t0)	# signal UART
1:	wfi					# wait for interrupt in loop
	j		1b

