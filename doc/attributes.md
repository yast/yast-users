# User And Group Attributes

This document describes the attributes that can be indicated for users and groups, either through the YaST UI of the *users* client or through AutoYaST. Each attribute should have a counterpart in the new *Y2Users* code. This correspondence helps to translate the users data structure from *Yast::Users* perl module to the new code.

## User

The YaST UI for creating and editing a user offers the following attributes:

| UI Field | Y2Users attr | Only when adding | Only when editing | Description |
| :--- | :--- | :--- | :--- | :--- |
| full name | gecos | | | |
| name | name | | | |
| password | password | | | |
| system mail | | | | |
| disable login | * password starting by `!` | | | |
| uid | uid | | | |
| home dir | home | | | | |
| home dir permission | | | | |
| empty home | | yes | | |
| Move to new location | | | yes |  |
| Btrfs subvolume | btrfs_subvolume_home | | | |
| Additional info | gecos | | | |
| login shell | shell | | | |
| group | primary_group | | | |
| additional groups | groups | | | |
| ssh public keys | authorized_keys | | | |

### Home management

### Creating a user

* A user can be created with or without home.
* To create a user without home, the *home dir* path should be set to empty.
* The home can be created with or without default content (*empty home* checkbox).
* The home can be created as Btrfs subvolume (*Btrfs subvol* checkbox).

### Editing a user

* If the home path is changed, then a new home is created with the default content.
* There is no way to create a new home without content (*empty home* checkbox is not available).
* If the *Move to new location* checkbox is marked, then the content of the old home is moved to the new one and the old home is removed.
* If the *Move to new location* checkbox is not marked, then the old home is kept.
* If the old home was a directory, then the new home is created as a directory again.
* If the old home was a subvolume, then the new home is created as a subvolume again.
* Side effects of *Move to new location* checkbox:
  * If the old home was a subvolume and *Move to new location* is not checked, then the new home is created as a directory instead of a subvolume.
* If the home path is removed, then the home is removed from the user but the home itself (directory or subvolume) is kept.
* There is no way to remove the home directory/subvolume.

### Deleting a user

* The home is removed too.


## Password

The YaST UI for creating and editing a user offers the following attributes for the password:

| UI Field | Y2Users attr | Only when adding | Only when editing | Description |
| :--- | :--- | :--- | :--- | :--- |
| force change  | aging == 0  | | | |
| days to warning | warning_period | | | |
| days usable after expiration | inactivity_period | | | |
| max days same password | maximum_age | | | |
| min days same password | minimum_age | | | |
| expiration date | account_expiration | | | |
