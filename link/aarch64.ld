OUTPUT_FORMAT(elf64-littleaarch64)
ENTRY(_start)

SECTIONS
{
  . = 0x40080000;
  PROVIDE(_kernel_start = .);

  .text : ALIGN(4K)
  {
    *(.text.boot)
    *(.text .text.*)
  }

  .rodata : ALIGN(4K)
  {
    *(.rodata .rodata.*)
  }

  .uefi_vector : ALIGN(8)
  {
    *(.uefi_vector)
  }

  .data : ALIGN(4K)
  {
    *(.data .data.*)
  }

  .bss : ALIGN(4K)
  {
    *(COMMON)
    *(.bss .bss.*)
  }

  . = ALIGN(16);
  stack_bottom = .;
  . += 0x100000;
  stack_top = .;

  . = ALIGN(4K);
  PROVIDE(_kernel_end = .);
}
