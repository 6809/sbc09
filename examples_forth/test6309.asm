* Test for 6309 instructions, compare with Forth assembler output.
  PSHSW
  PULSW
  PSHUW
  PULUW
  LDW ,W
  STW $1234,W
  ADDW ,--W
  SUBW ,W++
  ANDD [,W]
  ORD [$1234,W]
  EORD [,--W]
  CMPD [,W++]
  SEXW
  TFM X+,Y+
  TFM D-,U-
  TFM X+,D
  TFM U,X+
  ADDR A,B
  ADCR B,A
  ORR D,W
  ANDR W,Y
  EORR X,U
  CMPR E,F
  LDQ #$12345678
  LDQ <$1f
  STQ $1234
  ADDD E,X
  ADDD F,X
  ADDD W,X
  ASLD
  RORW
  COME
  INCF
  AIM #$80,<$12
  OIM #$40,$1234
  EIM #$20,5,U
  TIM #$10,,W
  LDBT A,1,0,$FE
  BOR  B,0,1,$FE
  STBT CC,0,7,$FE
  BIAND A,1,4,$FE
  MULD # $12
  DIVD # $12
  DIVQ [$1234]
  LDE #4
  STE [$34,X]
  LDMD #$01
  BITMD #$80
  PULU A, B, X, S
