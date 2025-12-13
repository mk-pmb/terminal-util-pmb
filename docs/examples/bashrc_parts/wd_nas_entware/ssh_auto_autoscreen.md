
If you want to automatically run autoscreen in your SSH session,
add SSH option `-t` to ensure your SSH client tries to allocate a TTY,
and pass this remote command:

```sh
bash -c 'source ~/.profile && exec autoscreen'
```

For GuTTY, which doesn't support custom session commands, you can instead
configure the default in your SSH config file:

```
Host wdnas.local
  SetEnv "gutty_ssh_args=bash -c 'source ~/.profile && autoscreen'"
```
