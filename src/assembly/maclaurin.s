# ==============================================================================
# Course: CS220 - Introduction to Computer Organization
# Project: 32-Bit MIPS Processor & FPGA Accelerator
# File: maclaurin.s
# Description: Maclaurin Series Expansion for e^x in MIPS Assembly (SPIM compatible).
#              Reads x (float) and N (integer, number of terms) from a binary
#              input file "input_exp.bin", evaluates the series using the recurrence
#              relation T(n) = T(n-1) * (x / n), logs step-by-step progress,
#              and writes results to "output_exp.txt".
# ==============================================================================

.data
    # File Paths
    fin_name:       .asciiz "input_exp.bin"
    fout_name:      .asciiz "output_exp.txt"

    # String templates for output logging
    header:         .asciiz "Maclaurin Series Expansion for e^x\n==================================\nTerm (n) |      Term Value      |      Cumulative Sum      \n----------------------------------------------------------\n"
    step_fmt_1:     .asciiz " | "
    newline:        .asciiz "\n"
    result_msg:     .asciiz "\n==================================\nApproximated e^x: "

    # Constants
    const_one:      .float 1.0
    const_zero:     .float 0.0
    const_ten_pow5: .float 100000.0   # For float-to-string conversion (5 decimal places)

    # I/O Buffers
    .align 2
    in_buf:         .space 8          # Stores x (float), N (int)
    out_buf:        .space 100        # Buffer for formatting step log strings

.text
.globl main

main:
    # --------------------------------------------------------------------------
    # 1. Open Input File "input_exp.bin"
    # --------------------------------------------------------------------------
    li $v0, 13              # Syscall 13: Open File
    la $a0, fin_name        # Filename
    li $a1, 0               # Read-only flag (0)
    li $a2, 0               # Mode (ignored)
    syscall
    move $s0, $v0           # $s0 = input file descriptor (fd_in)
    bltz $s0, err_exit      # If fd < 0, error

    # --------------------------------------------------------------------------
    # 2. Read 8 bytes (x, N) from Input File
    # --------------------------------------------------------------------------
    li $v0, 14              # Syscall 14: Read File
    move $a0, $s0           # fd_in
    la $a1, in_buf          # Buffer address
    li $a2, 8               # Read 8 bytes
    syscall
    move $s1, $v0           # $s1 = bytes read
    blt $s1, 8, err_exit    # Ensure we read all 8 bytes

    # Close Input File
    li $v0, 16              # Syscall 16: Close File
    move $a0, $s0           # fd_in
    syscall

    # Load parameters into registers
    l.s $f20, in_buf        # $f20 = x (float)
    lw $s2, in_buf+4        # $s2 = N (integer, terms count)

    # --------------------------------------------------------------------------
    # 3. Open Output File "output_exp.txt"
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
    li $a2, 149             # Length of header string
    syscall

    # --------------------------------------------------------------------------
    # 4. Evaluate Maclaurin Series Iteratively
    # --------------------------------------------------------------------------
    # Initialization:
    #   $f21 = Cumulative Sum (init to 1.0 for n=0)
    #   $f22 = Current Term Value (init to 1.0 for n=0)
    #   $s3  = Loop index (n = 0 to N)
    l.s $f21, const_one     # Sum = 1.0
    l.s $f22, const_one     # Term = 1.0
    li $s3, 0               # n = 0

log_term_0:
    # Log Term 0: n=0, Term=1.0, Sum=1.0
    jal log_step

loop_start:
    bge $s3, $s2, loop_end  # If n >= N, exit loop
    addi $s3, $s3, 1        # n = n + 1

    # Recurrence relation: T(n) = T(n-1) * (x / n)
    # Convert n to float
    mtc1 $s3, $f4           # Move n to FP coprocessor
    cvt.s.w $f4, $f4        # Convert n to float in $f4
    div.s $f6, $f20, $f4    # x / n
    mul.s $f22, $f22, $f6   # T(n) = T(n-1) * (x / n)

    # Sum = Sum + T(n)
    add.s $f21, $f21, $f22  # Sum = Sum + T(n)

    # Log Step
    jal log_step

    j loop_start

loop_end:
    # --------------------------------------------------------------------------
    # 5. Write Final Result and Close Output File
    # --------------------------------------------------------------------------
    # Write "Approximated e^x: " message
    li $v0, 15
    move $a0, $s0
    la $a1, result_msg
    li $a2, 53
    syscall

    # Format final sum into out_buf
    la $a0, out_buf
    mov.s $f12, $f21        # Sum
    jal format_float

    # Write final sum to file
    li $v0, 15
    move $a0, $s0
    la $a1, out_buf
    move $a2, $v1
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
# Logging Helper function: Writes one step log row to output file.
# Uses: $s3 (n), $f22 (Term value), $f21 (Cumulative Sum), $s0 (fd_out)
# ==============================================================================
log_step:
    # Save $ra on stack
    subu $sp, $sp, 4
    sw $ra, 0($sp)

    # Buffer start pointer
    la $s4, out_buf

    # Format term index (n)
    move $a0, $s3
    move $a1, $s4
    jal int_to_ascii
    add $s4, $s4, $v1

    # Append " | "
    la $a0, step_fmt_1
    move $a1, $s4
    jal str_copy
    add $s4, $s4, $v1

    # Format Term Value ($f22)
    mov.s $f12, $f22
    move $a0, $s4
    jal format_float
    add $s4, $s4, $v1

    # Append " | "
    la $a0, step_fmt_1
    move $a1, $s4
    jal str_copy
    add $s4, $s4, $v1

    # Format Cumulative Sum ($f21)
    mov.s $f12, $f21
    move $a0, $s4
    jal format_float
    add $s4, $s4, $v1

    # Append Newline
    la $a0, newline
    move $a1, $s4
    jal str_copy
    add $s4, $s4, $v1

    # Compute length of string in out_buf
    la $t0, out_buf
    sub $a2, $s4, $t0       # Length = current_ptr - start_ptr

    # Write to file
    li $v0, 15
    move $a0, $s0           # fd_out
    la $a1, out_buf
    syscall

    # Restore $ra and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
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
