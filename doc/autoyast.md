# AutoYaST Support

AutoYaST behaves in a different way depending whether it is running on 1st stage or not.

## 1st Stage

* Merges users/groups with the same name but keeping the original uid/gid (the one in the installed
  system).
* If a user/group element is not specified in the profile, it falls back to the existing value or
  the default as last resort.

For instance, given the following user:

```
foo:x:1000:100::/home/foo:/bin/zsh
```

and this profile excerpt:

```xml
<user>
  <username>foo</username>
  <fullname>Foo User</fullname>
  <uid>1001</uid>
  <gid>101</gid>
</user>
```

The resulting user is:

```
foo:x:1000:100:Foo User:/home/foo:/bin/zsh
```

A few things to note in this example:

* It retains the original uid (1000) and gid (100).
* As a shell is not defined, it keeps `/bin/zsh`.

## 2nd Stage or Normal Mode

* Merges users/groups with the same name and updates the configuration according to the profile.
* If an element is not specified in the profile, it falls back to the default.

Given the example of the previous section, the resulting user would be:

```
foo:x:1001:101:Foo User:/home/foo:/bin/bash
```
