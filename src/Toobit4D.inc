{ Toobit4D - common compiler settings (Delphi + FreePascal) }
{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}
{$Q-}  { overflow checking OFF: the SHA-256 code relies on 32-bit wrap-around }
{$R-}
