PROCESS BEFORE OUTPUT.
  MODULE status_2024.
  CALL SUBSCREEN mass_maintain INCLUDING sy-repid g_subscr_nn.

PROCESS AFTER INPUT.
  CALL SUBSCREEN mass_maintain.
  CHAIN.
    MODULE p_mass_maintain_validate.
  ENDCHAIN.
  MODULE user_command_2024.
