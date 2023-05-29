#!/bin/bash
ssh-keygen -t rsa -b 2048 -E sha256 -m PEM -O hashalg=sha256 -f $1-sig
ssh-keygen -f $1-sig.pub -e -m PEM > $1-sig.pub.pem

