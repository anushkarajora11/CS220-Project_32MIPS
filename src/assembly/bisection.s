# ==============================================================================
# Course: CS220 - Introduction to Computer Organization
# Project: 32-Bit MIPS Processor & FPGA Accelerator
# File: bisection.s
# Description: Recursive Bisection Algorithm in MIPS Assembly (SPIM compatible).
#              Reads initial interval [a, b] and tolerance (epsilon) from a binary
#              input file "input_bisect.bin", performs recursive root-finding for
#              f(x) = x^3 - x - 2.0 = 0, formats step results, and logs them to 
#              an ASCII text file "output_bisect.txt".
# ==============================================================================

.data
    # File Paths
    fin_name:       .asciiz "input_bisect.bin"
    fout_name:      .asciiz "output_bisect.txt"

    # String templates for output logging
    header:         .asciiz "Recursive Bisection Method Execution Log\n=========================================\nStep |      a      |      b      |      c      |     f(c)    \n---------------------------------------------------------\n"
    step_fmt_1:     .asciiz " "
    step_fmt_2:     .asciiz "    | "
    step_fmt_3:     .asciiz " | "
    newline:        .asciiz "\n"
    root_msg:       .asciiz "\n=========================================\nFinal Root Found: "

    # Constants
    const_two:      .float 2.0
    const_zero:     .float 0.0
    const_ten_pow5: .float 100000.0   # For float-to-string conversion (5 decimal places)

    # I/O Buffers
    .align 2
    in_buf:         .space 12         # Stores a (float), b (float), epsilon (float)
    out_buf:        .space 100        # Buffer for formatting step log strings

.text
.globl main

main:
    # --------------------------------------------------------------------------
    # 1. Open Input File "input_bisect.bin"
    # --------------------------------------------------------------------------
    li $v0, 13              # Syscall 13: Open File
    la $a0, fin_name        # Filename
    li $a1, 0               # Read-only flag (0)
    li $a2, 0               # Mode (ignored)
    syscall
    move $s0, $v0           # $s0 = input file descriptor (fd_in)
    bltz $s0, err_exit      # If fd < 0, error

    # --------------------------------------------------------------------------
    # 2. Read 12 bytes (a, b, epsilon) from Input File
    # --------------------------------------------------------------------------
    li $v0, 14              # Syscall 14: Read File
    move $a0, $s0           # fd_in
    la $a1, in_buf          # Buffer address
    li $a2, 12              # Read 12 bytes
    syscall
    move $s1, $v0           # $s1 = bytes read
    blt $s1, 12, err_exit   # Ensure we read all 12 bytes

    # Close Input File
    li $v0, 16              # Syscall 16: Close File
    move $a0, $s0           # fd_in
    syscall

    # Load parameters into FP registers
    l.s $f12, in_buf        # $f12 = a
    l.s $f13, in_buf+4      # $f13 = b
    l.s $f14, in_buf+8      # $f14 = epsilon

    # --------------------------------------------------------------------------
    # 3. Open Output File "output_bisect.txt"
    # --------------------------------------------------------------------------
    li $v0, 13              # Syscall 13: Open File
    la $a0, fout_name       # Filename
    li $a1, 1               # Write-only flag (1)
    li $a2, 0               # Mode (ignored)
    syscall
    move $s0, $v0           # $s0 = output file descriptor (fd_out)
    bltz $s0, err_exit      # If fd < 0, error

    # Write Header to Output File
    li $v0, 15              # Syscall 15: Write File
    move $a0, $s0           # fd_out
    la $a1, header          # Header string
    li $a2, 166             # Length of header string
    syscall

    # Initialize recursion variables
    li $s2, 0               # $s2 = Step counter = 0

    # Call Recursive Bisection
    # Arguments: $f12 = a, $f13 = b, $f14 = epsilon
    jal bisection_recurse

    # --------------------------------------------------------------------------
    # 4. Write Final Root and Close Output File
    # --------------------------------------------------------------------------
    # $f0 now holds the computed root
    mov.s $f12, $f0
    
    # Write "Final Root Found: " message
    li $v0, 15
    move $a0, $s0
    la $a1, root_msg
    li $a2, 60
    syscall

    # Format the final root into out_buf
    la $a0, out_buf
    mov.s $f12, $f0
    jal format_float

    # Write the formatted root string to file
    li $v0, 15
    move $a0, $s0
    la $a1, out_buf
    move $a2, $v1           # $v1 returned by format_float is the length
    syscall

    # Write final newline
    li $v0, 15
    move $a0, $s0
    la $a1, newline
    li $a2, 1
    syscall

    # Close Output File
    li $v0, 16
    move $a0, $s0           # fd_out
    syscall

err_exit:
    # Exit Program
    li $v0, 10              # Syscall 10: Exit
    syscall


# ==============================================================================
# Recursive Bisection Routine
# Inputs: 
#   $f12 = a (lower bound)
#   $f13 = b (upper bound)
#   $f14 = epsilon (tolerance)
#   $s2  = Step count (global/maintained)
#   $s0  = fd_out (output file descriptor)
# Outputs:
#   $f0  = computed root
# ==============================================================================
bisection_recurse:
    # Prologue: allocate stack frame and save registers
    subu $sp, $sp, 32
    sw $ra, 28($sp)
    s.s $f20, 24($sp)       # Save $f20 (a)
    s.s $f21, 20($sp)       # Save $f21 (b)
    s.s $f22, 16($sp)       # Save $f22 (c)

    mov.s $f20, $f12        # $f20 = a
    mov.s $f21, $f13        # $f21 = b

    # Increment Step Count
    addi $s2, $s2, 1

    # Compute midpoint: c = (a + b) / 2.0
    l.s $f4, const_two
    add.s $f6, $f20, $f21   # a + b
    div.s $f22, $f6, $f4    # c = (a + b) / 2.0

    # Compute f(c) = c^3 - c - 2.0
    mul.s $f4, $f22, $f22   # c^2
    mul.s $f4, $f4, $f22    # c^3
    sub.s $f4, $f4, $f22    # c^3 - c
    l.s $f6, const_two
    sub.s $f23, $f4, $f6    # f(c) = c^3 - c - 2.0 ($f23 = f(c))

    # --------------------------------------------------------------------------
    # Log Step: "Step | a | b | c | f(c)\n"
    # --------------------------------------------------------------------------
    # We will write the step log into out_buf and print it to the file.
    # Start buffering in out_buf
    la $s3, out_buf

    # Write Step counter
    move $a0, $s2
    move $a1, $s3
    jal int_to_ascii
    add $s3, $s3, $v1       # Move buffer pointer

    # Append " | "
    la $a0, step_fmt_2
    move $a1, $s3
    jal str_copy
    add $s3, $s3, $v1

    # Format 'a'
    mov.s $f12, $f20
    move $a0, $s3
    jal format_float
    add $s3, $s3, $v1

    # Append " | "
    la $a0, step_fmt_3
    move $a1, $s3
    jal str_copy
    add $s3, $s3, $v1

    # Format 'b'
    mov.s $f12, $f21
    move $a0, $s3
    jal format_float
    add $s3, $s3, $v1

    # Append " | "
    la $a0, step_fmt_3
    move $a1, $s3
    jal str_copy
    add $s3, $s3, $v1

    # Format 'c'
    mov.s $f12, $f22
    move $a0, $s3
    jal format_float
    add $s3, $s3, $v1

    # Append " | "
    la $a0, step_fmt_3
    move $a1, $s3
    jal str_copy
    add $s3, $s3, $v1

    # Format 'f(c)'
    mov.s $f12, $f23
    move $a0, $s3
    jal format_float
    add $s3, $s3, $v1

    # Append Newline
    la $a0, newline
    move $a1, $s3
    jal str_copy
    add $s3, $s3, $v1

    # Compute length of string in out_buf
    la $t0, out_buf
    sub $a2, $s3, $t0       # $a2 = length of formatted string

    # Write to file
    li $v0, 15
    move $a0, $s0           # fd_out
    la $a1, out_buf
    syscall

    # --------------------------------------------------------------------------
    # Check Termination: |b - a| < epsilon
    # --------------------------------------------------------------------------
    sub.s $f4, $f21, $f20   # b - a (since b > a, b-a is positive)
    c.lt.s $f4, $f14        # if (b - a) < epsilon
    bc1t base_case          # Branch to base case if true

    # Compute f(a) = a^3 - a - 2.0
    mul.s $f4, $f20, $f20   # a^2
    mul.s $f4, $f4, $f20    # a^3
    sub.s $f4, $f4, $f20    # a^3 - a
    l.s $f6, const_two
    sub.s $f8, $f4, $f6     # $f8 = f(a)

    # If f(a) * f(c) < 0, then root is in [a, c], recurse(a, c)
    mul.s $f4, $f8, $f23    # f(a) * f(c)
    l.s $f6, const_zero
    c.lt.s $f4, $f6         # if f(a)*f(c) < 0
    bc1t recurse_left       # Recurse on [a, c]

    # Else root is in [c, b], recurse(c, b)
    mov.s $f12, $f22        # New a = c
    mov.s $f13, $f21        # New b = b
    jal bisection_recurse
    j recurse_end

recurse_left:
    mov.s $f12, $f20        # New a = a
    mov.s $f13, $f22        # New b = c
    jal bisection_recurse
    j recurse_end

base_case:
    # Base case: return c as root
    mov.s $f0, $f22

recurse_end:
    # Epilogue: restore stack and return
    lw $ra, 28($sp)
    l.s $f20, 24($sp)
    l.s $f21, 20($sp)
    l.s $f22, 16($sp)
    addi $sp, $sp, 32
    jr $ra


# ==============================================================================
# Helper Utility Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# String Copy (str_copy)
# Copies asciiz string from $a0 to destination $a1.
# Returns string length in $v1.
# ------------------------------------------------------------------------------
str_copy:
    li $v1, 0
str_copy_loop:
    lb $t0, 0($a0)
    sb $t0, 0($a1)
    beqz $t0, str_copy_done
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    addi $v1, $v1, 1
    j str_copy_loop
str_copy_done:
    jr $ra

# ------------------------------------------------------------------------------
# Integer to ASCII (int_to_ascii)
# Converts integer in $a0 to decimal string at destination $a1.
# Returns string length in $v1.
# ------------------------------------------------------------------------------
int_to_ascii:
    # Save stack
    subu $sp, $sp, 16
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)

    move $s0, $a0           # Number
    move $s1, $a1           # Buffer Pointer
    li $s2, 0               # Digit counter

    # If 0
    bnez $s0, int_loop
    li $t0, '0'
    sb $t0, 0($s1)
    li $v1, 1
    j int_done

int_loop:
    beqz $s0, int_reverse
    li $t0, 10
    div $s0, $t0
    mflo $s0                # Quotient
    mfhi $t1                # Remainder (digit)
    addi $t1, $t1, 48       # Convert to ASCII character
    subu $sp, $sp, 1
    sb $t1, 0($sp)          # Store character on stack
    addi $s2, $s2, 1        # Increment count
    j int_loop

int_reverse:
    move $v1, $s2           # Return length
int_rev_loop:
    beqz $s2, int_done
    lb $t0, 0($sp)          # Pop from stack
    subu $sp, $sp, -1
    sb $t0, 0($s1)          # Store to buffer
    addi $s1, $s1, 1
    addi $s2, $s2, -1
    j int_rev_loop

int_done:
    lw $s0, 12($sp)
    lw $s1, 8($sp)
    lw $s2, 4($sp)
    addi $sp, $sp, 16
    jr $ra

# ------------------------------------------------------------------------------
# Format Float (format_float)
# Formats single precision float in $f12 as decimal string at destination $a0.
# Formats up to 5 decimal places (e.g. 1.23456 or -0.34212).
# Returns string length in $v1.
# ------------------------------------------------------------------------------
format_float:
    subu $sp, $sp, 20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)

    move $s0, $a0           # Destination buffer pointer
    move $s1, $s0           # Start pointer for length calculation

    # Handle negative floats
    l.s $f4, const_zero
    c.lt.s $f12, $f4        # If float < 0
    bc1f positive_float
    li $t0, '-'
    sb $t0, 0($s0)
    addi $s0, $s0, 1
    neg.s $f12, $f12        # Make absolute

positive_float:
    # Convert integer part to int
    cvt.w.s $f4, $f12       # Convert float to word
    mfc1 $a0, $f4           # Move word to integer register (Integer part)
    
    # Get float version of integer part
    mtc1 $a0, $f4
    cvt.s.w $f4, $f4
    sub.s $f6, $f12, $f4    # Fractional part = float - int_part

    # Print Integer Part to Buffer
    move $a1, $s0
    jal int_to_ascii
    add $s0, $s0, $v1

    # Print '.'
    li $t0, '.'
    sb $t0, 0($s0)
    addi $s0, $s0, 1

    # Convert fractional part to integer: fraction * 100000
    l.s $f8, const_ten_pow5
    mul.s $f6, $f6, $f8     # Shift decimal point 5 positions left
    cvt.w.s $f6, $f6        # Convert to word
    mfc1 $t0, $f6           # Move to integer register (Fraction as integer)
    
    # Ensure it's positive (in case of rounding edge cases)
    abs $t0, $t0

    # Print leading zeros if fraction is small (e.g. 0.00123 -> fraction int 123)
    # We want 5 digits. If less than 10000, print a '0', etc.
    li $t1, 10000
leading_zeros_loop:
    beqz $t1, print_fraction
    bge $t0, $t1, print_fraction
    li $t2, '0'
    sb $t2, 0($s0)
    addi $s0, $s0, 1
    div $t1, $t1, 10
    j leading_zeros_loop

print_fraction:
    move $a0, $t0
    move $a1, $s0
    jal int_to_ascii
    add $s0, $s0, $v1

    # Compute final string length
    sub $v1, $s0, $s1       # length = current_ptr - start_ptr
    sb $zero, 0($s0)        # Null terminate string

    lw $ra, 16($sp)
    lw $s0, 12($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 20
    jr $ra
