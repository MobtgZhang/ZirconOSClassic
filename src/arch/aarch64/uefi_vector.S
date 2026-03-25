/* UEFI ZBM scans the loaded kernel for magic 0x55454649 ("UEFI"). */
.section .uefi_vector, "a"
.align 8
.global uefi_vector
uefi_vector:
    .long 0x55454649
    .long 0
    .quad kernel_main
    .quad stack_top
