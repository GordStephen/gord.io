After several years of desktop-only computing for personal use, I recently
acquired a new-to-me laptop and figured it was time I finally
figured out what the deal was with full-drive encryption on Linux.

The Alpine Linux wiki includes a page stepping through an
["LVM on LUKS" install](https://wiki.alpinelinux.org/wiki/LVM_on_LUKS),
but my partitioning needs are pretty simple - I usually just use a catch-all
root partition with the EFI system partition mounted at /boot/efi. The more
general Alpine wiki page on
[setting up disks manually](https://wiki.alpinelinux.org/wiki/Setting_up_disks_manually)
mentions that you can set up an encrypted LUKS partition and just pass the
mapped mountpoint into `setup-disk`, but that will give you the default Alpine
partitioning scheme, with seperate root, boot, and swap partitions.

What follows is the final sequence of steps I took to achieve the simpler
partition scheme I wanted (with UEFI and GPT).
Most of this is adapted from the aforementioned LVM on LUKS guide, but there
were enough differences/simplifications/corrections involved that I figured
it was worth writing them down. You may want to consult that page as well for
additional information. Know that this is mainly the result of
combining fragments from the Alpine and Arch wikis, plus some educated
guessing, and lots of trial-and-error - I'm not an expert in any of this.
You results may vary...

## Basic Setup

To start, manually run the various Alpine setup scripts and rc commands:

```
# setup-keymap
# setup-hostname
# setup-interfaces
# rc-service networking start
# passwd
# setup-timezone
# rc-update add networking boot
# rc-update add urandom boot
# rc-update add acpid default
# rc-service acpid start
```

Edit `/etc/hosts` appropriately:

```
127.0.0.1	<hostname> <hostname>.localdomain localhost localhost.localdomain
::1		<hostname> <hostname>.localdomain localhost localhost.localdomain
```
Run some more setup scripts:

```
# setup-ntp
# setup-apkrepos
# apk update
# setup-sshd
```

## Partitioning, Encryption, and Formatting

At this point you should have a functional internet connection and package
database, which will let you install some additional packages to perform the
disk partitioning and encryption:

```
# apk add util-linux cryptsetup e2fsprogs dosfstools parted mkinitfs
```

`util-linux` gives you the `lsblk` command which you can use to figure out
the name of the storage device you want to install to. Here we'll assume
it's `/dev/sda`, and that your desired partition scheme looks like:

```
Partition             Filesystem  Note
============================================================
 /dev/sda1             fat32       EFI system partition
 /dev/sda2             LUKS        LUKS container
  ↳ /dev/mapper/crypt  ext4        Encrypted root partition
```

Nice and simple :) Let's create the two partitions on
`/dev/sda`, using `parted`:

```
# parted -a optimal /dev/sda
(parted) mklabel gpt
(parted) mkpart primary fat32 0% 200M
(parted) name 1 esp
(parted) set 1 esp on
(parted) mkpart primary ext4 200M 100%
(parted) name 2 crypto-luks
```

Now we can set up encryption on our newly-created `/dev/sda2` partition. Note
that with LUKS2, `cryptsetup` defaults to using the argon2id
PBKDF, which doesn't seem to work with GRUB. So we need to manually specify
pbkdf2 when formatting the partition:

```
# cryptsetup --pbkdf pbkdf2 luksFormat /dev/sda2
```

We can now open, format, and mount our newly-encrypted partition:

```
# cryptsetup luksOpen /dev/sda2 crypt
# mkfs.ext4 /dev/mapper/crypt
# mount -t ext4 /dev/mapper/crypt /mnt/
```

We can also format and mount the EFI system partition:

```
# mkfs.fat -F32 /dev/sda1
# mkdir -p /mnt/boot/efi
# mount -t vfat /dev/sda1 /mnt/boot/efi
```

`lsblk -f` is handy for checking your work.

At this point we're ready to install Alpine Linux to our mounted partitions:

```
# setup-disk -m sys /mnt/
```

Congratulations, Alpine Linux is now installed! Of course, that doesn't mean
it will boot yet...

# Bootloader, initial RAM disk, and decryption

It's worth noting that when we boot, our encrypted partition will need to be
decrypted twice: once for GRUB to access the kernel and initramfs, and a second
time to actually launch the OS. Providing the encryption password twice is a
bit of a pain, so instead we can define an alternate decryption keyfile for the
partition, which can be stored in the initramfs (only accessible
after the initial decryption) and used to decrypt the drive the second time.

Obviously, to do this you need to generate the keyfile _before_ you create the
initramfs. (For some reason the Alpine wiki page covers these topics in the
opposite order...)

To create the file and use it as a decryption key:

```
# touch /mnt/crypto_keyfile.bin
# chmod 600 /mnt/crypto_keyfile.bin
# dd bs=512 count=4 if=/dev/urandom of=/mnt/crypto_keyfile.bin
# cryptsetup luksAddKey /dev/sda2 /mnt/crypto_keyfile.bin
```

Now we need to configure the initramfs to do decryption and use the keyfile.
This is done by editing `/mnt/etc/mkinitfs/mkinitfs.conf` and appending
`cryptsetup` and `cryptkey` to the features parameter. The Alpine wiki mentions
some other modules (`kms`, etc) you may need to add as well.

With the keyfile in place and the configuration set up to use it, we can
regenerate the initial RAM disk:

```
# mkinitfs -c /mnt/etc/mkinitfs/mkinitfs.conf -b /mnt/ $(ls /mnt/lib/modules/)
```

If you want, you can inspect the contents of the initramfs file to confirm
that it contains the keyfile:

```
zcat /mnt/boot/initramfs-lts | cpio -t | less
```

Next we need to configure the bootloader. The wiki provides a neat tip for
writing the encrypted partition UUID into a file that you can easily read
into `vi` later:

```
blkid -s UUID -o value /dev/sda2 > /mnt/root/uuid
```

At this point we're almost ready to `chroot` into our new filesystem, which
is always exciting. First, mount a few more devices:

```
# mount -t proc /proc /mnt/proc
# mount --rbind /dev /mnt/dev
# mount --make-rslave /mnt/dev
# mount --rbind /sys /mnt/sys
```

Here we go! The wiki also suggests changing the prompt to make the
chroot environment more explicit:

```
# chroot /mnt
# source /etc/profile
# export PS1="(chroot) $PS1"
```

Now we can install GRUB in our new filesystem,
and remove syslinux if it's there:

```
(chroot) # apk add grub grub-efi efibootmgr
(chroot) # apk del syslinux
```

We're ready to start configuring GRUB. First we edit `/etc/default/grub` to
make sure the following are provided in the  `GRUB_CMDLINE_LINUX_DEFAULT`
parameter:

```
cryptroot=UUID=<UUID> cryptdm=crypt cryptkey
```

`<UUID>` is the UUID of the encrypted partition, which you can insert into the
file with the `:r /root/uuid` command in `vi` if you wrote it to a file as
discussed above.

In that same file, add the following additional parameters:

```
GRUB_PRELOAD_MODULES="luks cryptodisk part_gpt"
GRUB_ENABLE_CRYPTODISK=y
```

Next, create `/root/grub-pre.cfg` and populate it with:

```
set crypto_uuid=<UUID>
cryptomount -u $crypto_uuid
set root='crypto0'
set prefix=($root)/boot/grub
insmod normal
normal
```

Here, `<UUID>` is the encrypted partition's UUID again, but with the hyphens
removed this time.

We're almost done now. At this point it's worth checking your `/boot/efi`
mount point to see if the Alpine installation put anything there - in my case
I had existing GRUB images in `EFI/boot` and `EFI/alpine`. You could delete or
move these to avoid confusion, since we're about to re-install GRUB
(to `EFI/grub`) with the new configuration applied.

Speaking of which... Let's do a vanilla `grub-install` first, which will
create the necessary ancillary files in /boot and configure an EFI boot
variable. Then we'll install our customized GRUB image and config file:
 
```
(chroot) # grub-install --target=x86_64-efi --efi-directory=/boot/efi
(chroot) # grub-mkimage -p /boot/grub -O x86_64-efi -c /root/grub-pre.cfg \
                        -o /tmp/grubx64.efi luks2 part_gpt cryptodisk \
                           ext2 gcry_rijndael pbkdf2 gcry_sha256
(chroot) # install -v /tmp/grubx64.efi /boot/efi/EFI/grub/
(chroot) # grub-mkconfig -o /boot/grub/grub.cfg
```

To finish, `exit` the chroot and do some final cleanup:

```
# umount -l /mnt/dev
# umount -l /mnt/proc
# umount -l /mnt/sys
# umount /mnt/boot/efi
# umount /mnt
# cryptsetup luksClose crypt
```

Now, brave soul, you can `reboot` and see if it all worked.

If all goes well you should get an early password prompt from GRUB, before it
proceeds to its boot menu and, if the second keyfile decryption works,
the usual Linux startup process and login prompt.

If it doesn't work, there's a good chance the problem is somewhere in the
custom initramfs or bootloader configuration. You can repeat the "Basic Setup"
steps above to fully initialize the installer, decrypt `/dev/sda2` and re-mount
everything, and chroot into the filesystem to investigate.

A few things that tripped me up, in case they're helpful for you:

 - The default `cryptsetup luksFormat` command doesn't use pbkdf2 
 - If you can't get to the GRUB password prompt - you may not have your EFI
   boot variables for GRUB set correctly (or at all)
 - If you get prompted for a password twice, despite the keyfile: the initramfs
   may not be properly configured, or may not contain the keyfile

While it took me a few tries to get everything working, my hope is that the
outline above will make it a bit easier for you - good luck!
