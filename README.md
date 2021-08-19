# LVM Composer
Script that allows creating or extending Linux File Systems mounted on Logical volumes using Logical Volume Manager and a YAML configuration file.

You can create Volume groups with new disks, partition these disks, create Logical Volumes on top of these Volume groups, configure them for persistent mount on reboots, among other things. Just by setting the specifications of what you want to do in a YAML file with this format:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
  lvs:
    lv1:
      name: lvdata01
      size: 5G
      filesystem: xfs
      mountpoint: /mnt/data
      persistent: yes
 ```

The above setup will use disk **/dev/sdb** to create a volume group called **vgdata01** or extend it if this volume group already exists. It will also create a Logical Volume called **lvdata01** of 5gb on the volume group vgdata01, configured to work with an XFS file system, or it will extend it 5gb more if the logical volume already exists on said volume group. It will create the **/nmt/data** directory if it doesn't exist to mount the Logical Volume. You will also configure that mount point in the **/etc/fstab** file to automatically mount on every system reboot.

## Get started using:

Create an .yml file with the specifications of what you want to do with LVM and pass it as a parameter to **LVM_Composer.sh**:

```
# LVM_Composer.sh fileDataMapping.yml
```

### Creating the YAML configuration file:

To create or extend a Volume Group, you must create a new structured block with the data of the group volume, starting with the acronym VG followed by a block identification number, it must not have indentation. For example, for the first volume group, you can assign the block name **VG1**, if there is a second one, you can assign it **VG2**, **VG3** for a third, and so on:

- **Important note:** The indentation or tab stop for each sub parameter must be two spaces more than the parent parameter. No more no less. 

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
      
VG2:
  name: vgdata02
  disks:
    disk1: sdc
```

### Name of a volume group:

Use the **name** key to specify the name of the Volume group, this value is mandatory, if you omit it, the process will be canceled.

- **Important note:** If the established name already belongs to an existing vg, the disks will be used to make an extend of said vg. Be careful to name the VG you want to create correctly, as you could end up expanding an existing VG without intending to do so.

In the following example LVM Composer will try to create or extend a VG with the name **vgdata01**.

```
VG1:
  name: vgdata01  
```
However, this will result in an error as you have not set the disks with which to create or extend the VG.


### Disks in a volume group:

Use the **disks** key, plural, to configure the array of disks with which to create or extend this VG. To do this, each disk must be in a subparameter **disk**, in the singular, followed by the disk number to use in this vg, strictly it must always start with 1, whose value must be the name of the block device located in /dev.

The following example will try to create or extend a volume group with the name vgdata01, using the 100% capacity of the block device **/dev/sdb**:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
```

- **Important note:** Make sure the disks are new and without partitions already created. If LVM Composer detects that the disks are partitioned, it will abort the process. Still, make sure the names are correct to avoid any data loss.


With the following example, we will try to create or extend a volume group with the name vgdata01, using the 100% capacity of the block devices **/dev/sdb**, **/dev/sdc** and **/dev/nvme1**:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
    disk2: sdc
    disk3: nvme1
```

In the previous examples, all the space on the disks is used, creating in each one a single partition called by default "primary", using 100% of the disk capacity. You can set a custom name for this partition if you want. to do this, use the subparameter name, below the block device name.

With the following example, we will try to create or extend a volume group with the name vgdata01, using the 100% capacity of the block device **/dev/sdb**, which will have the default name "primary", and the 100% capacity of the block device **/dev/sdc** whose single partition would have the name **partTest1**:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
    disk2: sdc
      name: partTest1
```

For the case where you do not want to use 100% of the capacity of a disk or you want to have multiple partitions of a disk, you can use the sub-parameter **partition**, followed by the partition number, which must start at 1. Then add the partition data sub-parameters. Being the **size** parameter mandatory:

The following example will try to create or extend a volume group with the name vgdata01, using 15gb of the **/dev/sdb** block device. LVM Composer will create the 15gb partition with the name **partTest1** and the rest of the disk capacity will be available for anything else:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
      partition1:
        name: partTest1
        size: 15GB
```

If you do not specify the partition name, the default name "primary" will be used.

The following example will try to create or extend a volume group with the name vgdata01, using 50gb of the **/dev/sdb** block device. LVM Composer will create the 20gb partition with the default name **primary** and two more partitions of 15gb each with the names parTest1 and partTest2 respectively. The rest of the disk capacity will be available for something else:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
      partition1:
        size: 20GB
      partition2:
        name: partTest1
        size: 15GB
      partition3:
        name: partTest2
        size: 15GB
```

- **Important note:** The values for the parameter **size** of the partitions, must be expressed in gigabytes with the acronym **GB** in this version. This is intended to be resolved in later versions.



### Working with Logical Volumes:

The logical volumes configuration is set in the **lvs** key. There you can add the LV specifications for each volume group.

The specifications for each LV must start with the acronym **lv**, followed by the lv parameter identification number, starting with the number 1. For the first LV of the VG it would be **lv1**, for the second **lv2**, **lv3** for the third and so on:

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
  lvs:
    lv1:
      name: lvdata01
      size: 20G
    lv2:
      name: lvdata02
      size: 50G
    lv3:
      name: lvdata02
      size: 15G

```

In the following example, it will try to create or extend a volume group with the name vgdata01, using 100% of the disk /dev/sdb, then the LV named **lvdata01** will be created or extended. If the LV does not exist for the VG vgdata01, a new 20gb LV will be created, configured to work with the **XFS** filesystem, which will be mounted in the **/mnt/data** directory, if this directory does not exists, it will create it.

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
  lvs:
    lv1:
      name: lvdata01
      size: 20G
      filesystem: xfs
      mountpoint: /mnt/data
```

- **Important note:** The values for the parameter **size** of the Logical volumes must be expressed in gigabytes with the letter **G** in this version. This is intended to be resolved in later versions.

The **persistent** parameter with the value **yes** indicates that the mount point must be configured in the **/etc/fstab** file to make it persistent on system reboots. By default the value of this parameter is **no**.

```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
  lvs:
    lv1:
      name: lvdata01
      size: 20G
      filesystem: xfs
      mountpoint: /mnt/data
      persistent: yes
```

You can configure a comment for the fstab file with the **description** parameter as shown in the following example:
```
VG1:
  name: vgdata01
  disks:
    disk1: sdb
  lvs:
    lv1:
      name: lvdata01
      size: 20G
      filesystem: xfs
      mountpoint: /mnt/data
      persistent: yes
      description: This is LV created with LVM Composer.
```


### General features:

The disk partitioning scheme used by LVM_composer.sh by default is GPT.

