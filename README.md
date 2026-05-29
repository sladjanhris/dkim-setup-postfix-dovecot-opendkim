# dkim-setup-postfix-dovecot-opendkim
A Bash script to automate DKIM key generation and OpenDKIM configuration for multiple domains on a Postfix mail server.

## What It Does

Given a list of domains, the script:

1. Generates a DKIM keypair (private + public) for each domain using `opendkim-genkey`, skipping any domain that already has keys
2. Sets correct file permissions and ownership for the OpenDKIM user
3. Appends entries to the three OpenDKIM config files (`KeyTable`, `SigningTable`, `TrustedHosts`), skipping entries that already exist (idempotent)
4. Restarts OpenDKIM and reloads Postfix to apply changes

All keys are stored under `/etc/dkimkeys/<domain>/` using the `default` selector.

---

## Requirements

- Linux server (Debian/Ubuntu recommended)
- `opendkim` and `opendkim-tools` installed
- `postfix` installed and running
- Script must be run as **root**

```bash
apt install opendkim opendkim-tools
```

---

## Usage

**1. Clone the repo**

```bash
git clone https://github.com/sladjanhris/dkim-setup-postfix-dovecot-opendkim.git
cd dkim-setup-postfix-dovecot-opendkim
```

**2. Create your `domains.txt`**

One domain per line:

```
example.com
mail.yourdomain.com
anotherdomain.io
```

**3. Run the script**

```bash
chmod +x dkim-setup.sh
sudo ./dkim-setup.sh
```

---

## Output

After running, each domain will have:

```
/etc/dkimkeys/
└── example.com/
    ├── default.private   # Private signing key (kept on server)
    └── default.txt       # Public key → publish this as a DNS TXT record
```

The script also updates:

| File | Purpose |
|------|---------|
| `/etc/dkimkeys/KeyTable` | Maps selector/domain to private key path |
| `/etc/dkimkeys/SigningTable` | Maps outgoing addresses to signing keys |
| `/etc/dkimkeys/TrustedHosts` | Domains trusted to sign via OpenDKIM |

---

## DNS Setup

After running the script, publish the public key for each domain as a DNS TXT record.

**Record name:**
```
default._domainkey.example.com
```

**Record value:** copy from `/etc/dkimkeys/example.com/default.txt` — it looks like:

```
v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhki...
```

Allow up to 48 hours for DNS propagation, then verify with:

```bash
opendkim-testkey -d example.com -s default -vvv
```

---

## Configuration

Edit the variables at the top of the script if your setup differs:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAINS_FILE` | `domains.txt` | Path to the domain list |
| `DKIM_BASE` | `/etc/dkimkeys` | Base directory for keys and config files |
| `OPENDKIM_USER` | `opendkim` | System user that owns the key files |
| `OPENDKIM_GROUP` | `opendkim` | System group for key file ownership |
| `SELECTOR` | `default` | DKIM selector name used in DNS and config |

---

## Notes

- **Idempotent** — safe to re-run. Existing keys and config entries are never overwritten or duplicated.
- The script does **not** configure `/etc/opendkim.conf` itself — make sure your OpenDKIM config already points to the `KeyTable`, `SigningTable`, and `TrustedHosts` files at `/etc/dkimkeys/`.
- To use a different selector (e.g. for key rotation), change the `SELECTOR` variable before running.

---

## License

MIT
