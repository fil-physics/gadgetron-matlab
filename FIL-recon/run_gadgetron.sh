#!/bin/bash
# -s defines port on which storage server is run
# -D defines where the storage server database is located (workaround when no permisions to access default database)
# grep -v DEBUG - is to suppress over-verbose FIRE scaling messages
gadgetron -p9888  -s 9111 -D "/root/.gadgetron/storage/database-FIL" | grep -v DEBUG
