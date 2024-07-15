# Used to generate an offline version of the disko config
# which can be used independent of the nix flake.
#
# This allows avoiding an embed of the full flake
# closure in the iso image which adds significant eval
# time and image size.
import ./airgap-data.nix (import ./image-parameters.nix)
