# Command line tool for tsrct

## Initializing a domain

```text
tsrct domain dns \
  --key-set-id <key set id shown in tsrct> \
  --uid <desired uid selected for this domain> \
  --key-host gcp \
  --sig-key-resource <signature key resource, fully qualified path for host, INCLUDING VERSION NUMBER> \
  --enc-key-resource <encryption key resource, fully qualified path for host, INCLUDING VERSION NUMBER> 
```

you will receive output that contains entries to put as TXT records in your DNS provider against your domain, such as:
`tsrct-domain-verification[0]=Yj27...Iec0xHLPWV`
`tsrct-domain-verification[1]=O1CPK...Yz39`
`tsrct-domain-verification[2]=PKYjwy...8ewUeubz39I`
`tsrct-domain-verification[3]=CK2b1...yeUb39Iecx`

enter each one of the above into your DNS TXT records and way for them to go live. You can check for their availability 
from the command line by using (on Mac/Unix):
`dig <domain> TXT`

now you can initiate the process of registering the domain:
```text
tsrct domain init \
  --dom <your domain, such as tsrct.io> \
  --key-set-id <key set id shown in tsrct> \
  --uid <desired uid selected for this domain> \
  --key-host gcp \
  --sig-key-resource <signature key resource, fully qualified path for host, INCLUDING VERSION NUMBER> \
  --enc-key-resource <encryption key resource, fully qualified path for host, INCLUDING VERSION NUMBER> 
  
```