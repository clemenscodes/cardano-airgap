{
  imageParameters = rec {
    # Set to false when ready to generate and distribute an image
    testImage = false;

    # This will add significant eval time and size to the image,
    # but may fix a problem if a flake related nix operation
    # can't complete within the airgap image.
    embedFlakeDeps = false;

    # Required for the image disko offline formatter script
    etcFlakePath = "flake";

    publicVolName = "public";
    encryptedVolName = "encrypted";

    documentsDir = "/run/media/${signingUser}/${publicVolName}";
    secretsDir = "/run/media/${signingUser}/${encryptedVolName}";

    hostId = "ffffffff";
    hostName = "cc-airgap";

    signingUser = "cc-signer";
    signingUserUid = 1234;
    signingUserGid = 100;
    signingUserGroup = "users";
  };
}
