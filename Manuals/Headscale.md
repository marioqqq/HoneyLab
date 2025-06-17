Create user `docker exec headscale headscale users create USERNAME`

To connect phone, download Tailscale app. Close login and open Settings/Accounts/3 dots/ Use an alternate server. Put your URL and copy its content to the server 
```bash
docker exec headscale headscale nodes register --user USERNAME --key randomstring
docker exec headscale headscale nodes list
docker exec headscale headscale nodes rename new-name -i id-from-nodes-list
```

To connect Windows PC, run in terminal `tailscale login --login-server headscale-url` and continue as shown before.

To connect Tailscale container for LAN access, run on Headsclale server 
```bash
docker exec headscale headscale preauthkeys create --user id-from-users-list
```
Copy the key to .env file and run the container.
```bash
docker exec headscale headscale nodes list
docker exec headscale headscale nodes rename new-name -i id-from-nodes-list
docker exec headscale headscale nodes routes list
docker exec headscale headscale nodes approve-routes --identifier id-from-routes-list --routes ip/subnet-mask
docker exec headscale headscale nodes routes list
```
Then on the client side run:
```bash
docker exec tailscale tailscale set --accept-routes
```