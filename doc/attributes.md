# User And Group Attributes

This document describes the attributes that can be indicated for users and groups, either through the YaST UI of the *users* client or through AutoYaST. Each attribute should have a counterpart in the new *Y2Users* code. This correspondence helps to translate the users data structure from *Yast::Users* perl module to the new code.

## User

The YaST UI for creating and editing a user offers the following attributes:

| UI Field | Y2Users attr | Usage | Description |
| :--- | :--- | :--- | :--- |
| full name | `#gecos` | add && edit | |
| name | `#name` | add && edit  | |
| password | `#password` | add && edit  |
| system mail | `#receive_system_mail` | add && edit | See `MailAliases` module |
| disable login | * password starting by `!` | add && edit | |
| uid | `#uid` | add && edit | |
| home dir | `Home#path` | add && edit | |
| home dir permission | `Home#permissions` | add | | `useradd -K HOME_MODE=0755` |
| empty home | `CommitConfig#home_without_skel` | add | | `rm -rf` after creating. No way to ignore `/usr/etc/skel` |
| Move to new location | `CommitConfig#move_home` | edit |  |
| Btrfs subvolume | `Home#btrfs_subvol` | add && edit | |
| Additional info | `#gecos` | add && edit | |
| login shell | `#shell` | add && edit | |
| group | `#primary_group` | add && edit | |
| additional groups | `#groups` | add && edit | |
| ssh public keys | `#authorized_keys` | add && edit | |


## Password

The YaST UI for creating and editing a user offers the following attributes for the password:

| UI Field | Y2Users attr | Usage | Description |
| :--- | :--- | :--- | :--- |
| force change  | aging == 0  | add && edit | |
| days to warning | warning_period | add && edit | |
| days usable after expiration | inactivity_period | add && edit | |
| max days same password | maximum_age | add && edit | |
| min days same password | minimum_age | add && edit | |
| expiration date | account_expiration | add && edit | |


## Home management

This section describes how the YaST users client behaves when dealing with the user home.

#### Creating a user

* A user can be created with or without home.
* To create a user without home, the *home dir* path should be set to empty.
* The home can be created with or without default content (*empty home* checkbox).
* The home can be created as Btrfs subvolume (*Btrfs subvol* checkbox).
* The home can be created with custom permissions (*Home permissions* field).
* If the home already exists, it asks for adapting ownership.

#### Editing a user

* If the home path is changed, then a new home is created with the default content.
* If the home already exists, it asks for adapting ownership.
* There is no way to create a new home without content (*empty home* checkbox is not available).
* If the *Move to new location* checkbox is marked, then the content of the old home is moved to the new one and the old home is removed.
* If the *Move to new location* checkbox is not marked, then the old home is kept.
* If the old home was a directory, then the new home is created as a directory again.
* If the old home was a subvolume, then the new home is created as a subvolume again.
* Side effects of *Move to new location* checkbox:
  * If the old home was a subvolume and *Move to new location* is not checked, then the new home is created as a directory instead of a subvolume.
* If the home path is removed, then the home is removed from the user but the home itself (directory or subvolume) is kept.
* There is no way to remove the home directory/subvolume.

#### Deleting a user

* The user is asked whether to keep or remove home.

#### Home representation in `Y2Users`

~~~
Y2Users::Home
  #path
  #permissions
  #btrfs_subvol
~~~

* Use cases
  * create a new user with a home (`Home#path` is not empty)
    * if the path already exists:
      * re-use existing home
      * adapt ownership (`CommitConfig#adapt_home_ownership`)
    * if the path does not exist:
      * create new home as dir/subvolume (`Home#btrfs_subvol`)
      * create with/without content (`CommitConfig#home_without_skel`)
      * create with custom permissions (`Home#permissions`)
  * create a new user without a home (`Home#path` is empty)
    * do not create a home on disk
  * edit a user and change the home (`Home#path` changes)
    * if the path already exists:
      * re-use existing home
      * adapt ownership (`CommitConfig#adapt_home_ownership`)
    * if the path does not exist:
      * if the home should be moved (`CommitConfig#move_home`)
        * move home
      * if the home should not be moved:
        * create a home (TODO: Not supported by shadow tools)
        * do not remove old home from disk
  * edit a user and remove the home (`Home#path` is empty)
    * do not remove old home from disk
  * delete a user (TODO)
