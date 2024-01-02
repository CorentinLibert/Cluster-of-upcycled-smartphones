# Perpetronic toolchain

## Problems

1. In `appsystem.conf`, 
    - `PERPETRONIC_SRC_DIR` should be relative to the current user, not absolute to **nbrusselmans**.
    - `PERPETRONIC_CA_PKI_DIR="$PERPETRONIC_SRC_DIR/VPN-PKI/BrockCA/pki"`, relative or absolute ?
2. For `PERPETRONIC_BASE_HOSTNAME` and `PERPETRONIC_BASE_FIXED_IP`, where do I find the serial number ???
3. Some errors happen with Services ? SOLITION: Remove them from the `appsystem.conf` (need more doc)
4. Before running script, check requirements and install them:
    - `../../Perpetronic/versabrain/build/perpetronic.sh: line 531: fastboot: command not found`
5. 