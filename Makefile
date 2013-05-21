PREFIX=/usr/local

.PHONY: client server

client: client/dynd.sh
	install -D -m 0755 client/dynd.sh $(DESTDIR)$(PREFIX)/bin/dynd

server: server/dynd.conf
	@echo "Just copy server/dynd.conf to your bind configuration and include it!"
	@echo "Check README.md for full information"
