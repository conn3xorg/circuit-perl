# Local example

Applies circuit-perl to a throwaway Rocky Linux 10 container with systemd, installing Perl, Try::Tiny from the distribution's packages, and Text::Trim 1.04 from CPAN. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To see both modules load, and where from:

```sh
ssh -p 2310 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 \
  'perl -MTry::Tiny -MText::Trim -e "print qq{\$INC{q{Try/Tiny.pm}}\n\$INC{q{Text/Trim.pm}}\n}"'
```

`up.sh` listens on `127.0.0.1:2310`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
