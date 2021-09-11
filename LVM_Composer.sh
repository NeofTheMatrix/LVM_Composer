#!/bin/bash
# LVM Composer 1.0
# Por: Anderson J. Campos R. - 2021

toDay=$(date +%d-%m-%Y)
toHour=$(date +"%I%M%S")
HOUR=$(date +"%I:%M %p")

red=`tput setaf 9`
yellow=`tput setaf 11`
green=`tput setaf 14`
reset=`tput sgr0`


echo "${green}(i) ¡Bienvenido a LVM Composer!"
echo "${green}(i) Tomando evidencias previas del estado actual del storage en este servidor...${reset}"
sleep 2
echo "" > LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Dispositivos de bloque en este servidor antes de iniciar el proceso ($(hostname) - $toDay $HOUR):${reset}" | tee -a LVM_composer_before_$toDay_$toHour.out
lsblk -l | tee -a LVM_composer_before_$toDay_$toHour.out
echo "-------------------------------------------------" | tee -a LVM_composer_before_$toDay_$toHour.out
lsblk | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out 
echo "${green}(i) Physical volumes en este servidor antes de iniciar el proceso:${reset}"
pvdisplay | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Volumen Groups en este servidor antes de iniciar el proceso:${reset}"
vgdisplay | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Logical volumes en este servidor antes de iniciar el proceso:${reset}"
lvdisplay | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Estructura del File System de este servidor:${reset}"
df -hT | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Contenido del archivo /etc/fstab:${reset}"
cat /etc/fstab | tee -a LVM_composer_before_$toDay_$toHour.out

echo -e "\n\n"
echo "${green}(i) Se dejaron las evidencias del estado actual del storage de este servidor en el archivo: LVM_composer_before_$toDay_$toHour.out ${reset}"

echo -e "\n\n\n\n"

parse_yaml() {
  
  local prefix=$2
  local s='[[:space:]]*'
  local w='[a-zA-Z0-9_]*'
  local fs=$(echo @|tr @ '\034')
  
  sed "h;s/^[^:]*//;x;s/:.*$//;y/-/_/;G;s/\n//" $1 |
  sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
      -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" |
  awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;

    for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
  }'
}

eval $(parse_yaml $1 "LVM_")

for VG in $(grep -Ew 'VG[0-9]{1,6}:' $1 | grep -Eo 'VG[0-9]{1,6}'); do
	
	vgName="LVM_${VG}_name"

	# Verificar si se especificó un nombre para el VG, de lo contrario se cancela la operación:
	if [[ ${!vgName} ]]; then

		echo -e "\n\n${green}(i) Iniciando proceso para el ${VG}: ${!vgName} ${reset}"
		sleep 2

		# Preparar los discos para este VG:
		disksCount=1
		# Arreglo de discos que no requieren más de una partición:
		declare -a noPartitionedDisk=()
		# Arreglo de discos que pueden requerir más de una partición:
		declare -a partitionedDisk=()
		while true; do
			disk="LVM_${VG}_disks_disk${disksCount}"

			if [[ ${!disk} ]]; then
				# Verificar si el archivo del disco existe en /dev y que esté disponible:
				if [[ $(ls /dev | grep -w ${!disk} | wc -l) -lt 1 ]]; then
					echo "${red}(X) No existe el archivo de dispositivo /dev/${!disk} ${reset}"
					exit 2
				else
					# Verificar si ya es parte de un PV:
					if [[ $(pvdisplay | grep ${!disk} | wc -l) -gt 0 ]]; then
						echo "${red}(X) El disco ${!disk} ya se encuentra etiquetado como un Physical volume, por lo que puede que ya esté en uso.${reset}"
						exit 3				
					fi

					# Verificar si tiene particiones:
					if [[ $(lsblk -l | grep ${!disk} | grep part | wc -l) -gt 0 ]]; then
						echo "${red}(X) El disco ${!disk} ya tiene particiones creadas, por lo que puede que ya esté en uso.${reset}"	
						exit 4			
					fi

				fi

				echo "${green}(i) Se usará el disco ${!disk} para VG ${!vgName}. ${reset}"

				# Verificar si se requiere particionar este disco
				partitionCount=1
				startPartition="2048s"
				lastPartitionedDisk=""

				while true; do
					partitionSize="LVM_${VG}_disks_disk${disksCount}_partition${partitionCount}_size"
					partitionName="LVM_${VG}_disks_disk${disksCount}_partition${partitionCount}_name"

					# Si hay particiones para crear:
					if [[ ${!partitionSize} ]]; then

						lastPartitionedDisk="${!disk}"

						if [[ ${!partitionName} ]]; then
							partitionName=${!partitionName}
							echo "${green}(i) Se creará la partición $partitionCount para el disco ${!disk} de ${!partitionSize} con el nombre $partitionName.${reset}"
						else
							partitionName="primary"
							echo "${green}(i) Se creará la partición $partitionCount para el disco ${!disk} de ${!partitionSize} con el nombre por defecto $partitionName.${reset}"
						fi

						# Si es la primera partición a crear:
						if [[ $partitionCount -eq 1 ]]; then
							echo "${green}(i) Creando la primera partición del disco ${!disk}, de tipo LVM con el esquema GPT.${reset}"
							startPartition="2048s"
							# Se crea la primera partición etiquetando el disco con el esquema GPT
							parted -s /dev/${!disk} mklabel gpt mkpart $partitionName $startPartition ${!partitionSize}
							udevadm settle
							parted -s /dev/${!disk} set $partitionCount lvm on

							startPartition=${!partitionSize}

							parted /dev/${!disk} print
						else
							
							partitionEnd=$(($(echo $startPartition | awk -F"GB" '{ print $1 }') + $(echo ${!partitionSize} | awk -F"GB" '{ print $1 }')))
							partitionEnd="${partitionEnd}GB"

							echo "${green}(i) Creando otra partición del disco ${!disk}, de tipo LVM. Start: $startPartition, End: $partitionEnd ${reset}"

							parted -s /dev/${!disk} mkpart $partitionName $startPartition $partitionEnd
							udevadm settle
							parted -s /dev/${!disk} set $partitionCount lvm on

							startPartition=$partitionEnd

							parted /dev/${!disk} print
						fi
						
						partitionedDisk=( "${partitionedDisk[@]}" ${!disk}$partitionCount )
						((partitionCount+=1))
					else
						if [[ $lastPartitionedDisk != ${!disk} ]]; then
							noPartitionedDisk=( "${noPartitionedDisk[@]}" ${!disk} )
						fi
						break
					fi

				done

				((disksCount+=1))
			else
				# Si no se configuró "disk1", se cancela la operación:
				if [[ $disksCount -eq 1 ]]; then 
					echo "${red}(X) No se especificó ningún disco para el ${VG}: ${!vgName} ${reset}"
					exit 5
				fi
				break
			fi
		done

		((disksCount-=1))
		# Para los discos que no requieren varias particiones se tomará el disco completo:
		for disk in "${noPartitionedDisk[@]}"; do
			
			#disk="LVM_${VG}_disks_disk${diskNum}"
			diskName="primary"

			for diskNum in $( seq 1 $disksCount ); do
				cnfDisk="LVM_${VG}_disks_disk${diskNum}"

				if [[ ${!cnfDisk} = $disk ]]; then
					diskName="LVM_${VG}_disks_disk${diskNum}_name"

					if [[ ${!diskName} ]]; then
						diskName=${!diskName}
						echo "${green}(i) Se creará una partición unica, tomando el 100% del espacio del disco /dev/$disk. La partición se llamará $diskName. ${reset}"
					else
						diskName="primary"
						echo "${green}(i) Se creará una partición unica con el esquema GTP, tomando el 100% del espacio del disco /dev/$disk. La partición se llamará $diskName. ${reset}"
					fi

					break
				fi

			done

			#echo "Preparar disco físico: parted -s /dev/${!disk} mkpart ${!diskName} 2048s 100% "
			echo "${green}(i) Creando partición del 100% del disco /dev/$disk con el esquema GTP.${reset}"
			parted -s /dev/$disk mklabel gpt mkpart $diskName 2048s 100%
			udevadm settle
			parted -s /dev/$disk set 1 lvm on

			parted /dev/$disk print
		done

		# Crear los PV con los discos ya particionados:
		disksForVG=""
		# Discos con una sola partición:
		for disk in "${noPartitionedDisk[@]}"; do
			disksForVG="$disksForVG /dev/${disk}1"
		done
		# Discos con una o más de una partición:
		for disk in "${partitionedDisk[@]}"; do
			disksForVG="$disksForVG /dev/${disk}"
		done

		echo "${green}(i) Se etiquetarán los siguientes discos como Physical volume: $disksForVG ${reset}"
		pvcreate $disksForVG
		echo "${green}(i) Physical volumes creados:${reset}"
		pvdisplay $disksForVG

		# Verificar si el Volumen Group indicado existe para ampliar, de lo contrario, se creará un VG nuevo con el nombre indicado:
		if [ $(vgdisplay ${!vgName} | grep "VG UUID" | wc -l) -gt 0 ]; then
			echo "${green}(i) Se detectó un VG existente con el nombre ${!vgName}. Se procederá a la ampliación de este VG.${reset}"
			vgextend ${!vgName} $disksForVG
			echo "${green}(i) Información del volume group ${!vgName} extendido:${reset}"
		else
			echo "${green}(i) No se detectó un vg existente con el nombre ${!vgName}. Se procederá a crear uno nuevo.${reset}"
			vgcreate ${!vgName} $disksForVG
			echo "${green}(i) Información del volume group ${!vgName} creado:${reset}"

		fi

		vgdisplay ${!vgName}


		# Trabajando con LV's:
		lvCount=1
		requireMount=""
		while true; do
			lvOrderMount="LVM_${VG}_lvs_ordermount"
			lvMountAfter="LVM_${VG}_lvs_mountafter"
			lvName="LVM_${VG}_lvs_lv${lvCount}_name"
			lvSize="LVM_${VG}_lvs_lv${lvCount}_size"
			lvFS="LVM_${VG}_lvs_lv${lvCount}_filesystem"
			lvMountPoint="LVM_${VG}_lvs_lv${lvCount}_mountpoint"
			lvPersistent="LVM_${VG}_lvs_lv${lvCount}_persistent"
			lvdescription="LVM_${VG}_lvs_lv${lvCount}_description"

			lvfileSystem=${!lvFS}

			# Verificar si se pide la creación de LVs:
			if [[ ${!lvName} ]]; then

				# Verificar si el LV no existe, para crearlo, de lo contrario se realiza el extend:
				if [ $(lvdisplay ${!vgName} | grep "LV Name" | grep ${!lvName} | wc -l) -gt 0 ]; then
					# Realizar extend al LV existente de este VG:
					echo "${green}(i) Se detectó un LV existente con el nombre ${!lvName} en este VG. Se procederá a la ampliación de este LV.${reset}"
					lvextend -L +${!lvSize} /dev/${!vgName}/${!lvName}
					echo "${green}(i) Información del Logical volume ${!vgName} extendido:${reset}"
					lvdisplay /dev/${!vgName}/${!lvName}
				else
					# Crear nuevo LV en este VG:
					echo "${green}(i) No se detectó un LV existente con el nombre ${!lvName} en este VG. Se procederá a crear un nuevo LV.${reset}"
					lvcreate -n ${!lvName} -L ${!lvSize} ${!vgName}
					echo "${green}(i) Información del Logical volume ${!vgName} creado:${reset}"
					lvdisplay /dev/${!vgName}/${!lvName}

					# Agregar el sistema de archivos.
					if [[ ${!lvFS} ]]; then
						echo "${green}(i) Agregando en sistema de archivos ${!lvFS} al LV ${!lvName} ${reset}"
						mkfs -t ${!lvFS} /dev/${!vgName}/${!lvName}
					else
						lvfileSystem="xfs"
						echo "${yellow}[!] ATENCION: No se especificó un file system para el LV ${!lvName}. Se agregará el file system por defecto xfs.${reset}"
						mkfs -t xfs /dev/${!vgName}/${!lvName}
					fi
					# Crear el punto de montura si no existe:
					if [[ ${!lvMountPoint} ]]; then
						mkdir -p ${!lvMountPoint}
						# Hacer el punto de montura persitente si se requiere:
						if [ ${!lvPersistent} = "yes" ]; then

							echo "${green}(i) Creando archivo de respaldo /etc/fstab_backup_${toDay}_${toHour} ${reset}"
							cp /etc/fstab /etc/fstab_backup_${toDay}_${toHour}

							# Verificar si el fstab ya tiene este punto de montura configurado:
							if [[ $(awk '{print $2}' /etc/fstab | grep "^${!lvMountPoint}$" | wc -l) -eq 1 ]]; then
								# Verificar si está configurado para ser montado sobre el mismo VG y LV, sino reemplazar:
								if [ $(grep /dev/${!vgName}/${!lvName} /etc/fstab | awk '{print $2}' | grep "^${!lvMountPoint}$"  | wc -l) -gt 0  || $(grep $(blkid | grep /dev/mapper/${!vgName}-${!lvName} | awk '{print $2}') /etc/fstab | wc -l) -gt 0 ]; then
									# Hay que verificar si tiene la configuración de orden de montura, si esta es requerida:
									if [[ ${!lvOrderMount} = "yes" ]]; then
										#statements
										if [[ ${!lvMountAfter} ]]; then
											sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults,x-systemd.requires-mounts-for=${!lvMountAfter}   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
										else
											sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
										fi
									else
										echo "${green}(i) Se detectó que el directorio ${!lvMountPoint} ya se encuentra configurado en el /etc/fstab para ser montado sobre /dev/${!vgName}/${!lvName}. No se realizarán cambios en el /etc/fstab para este LV.${reset}"
									fi
								else
									echo "${yellow}[!] ATENCION: El directorio ${!lvMountPoint} se encuentra configurado en el /etc/fstab para ser montado sobre un File System diferente al /dev/${!vgName}/${!lvName}. Realizando cambios en el archivo /etc/fstab para montarlo sobre /dev/${!vgName}/${!lvName}.${reset}"
									lineToReplace=$(awk '{print $2}' /etc/fstab | grep "^${!lvMountPoint}$")

									# Configurar el orden de montura de los FileSystem:
									if [[ ${!lvOrderMount} = "yes" ]]; then
										# Si es el primero, establece la configuración normal
										if [[ ${lvCount} -eq 1 ]]; then

											if [[ ${!lvMountAfter} ]]; then
												sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults,x-systemd.requires-mounts-for=${!lvMountAfter}   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
											else
												sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
											fi

										else
											sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults,x-systemd.requires-mounts-for=$requireMount   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
										fi
									else
										sed "/^$lineToReplace/c \/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults   0 0" /etc/fstab | tee tempLVMComposer_confPersistent.txt; cat tempLVMComposer_confPersistent.txt > /etc/fstab
									fi

									rm -f tempLVMComposer_confPersistent.txt
								fi
							else
								echo "${green}(i) Agregando la configuración del File System en el archivo /etc/fstab.${reset}"
								if [[ ${!lvdescription} ]]; then
									echo "" >> /etc/fstab
									echo "# ${!lvdescription}" >> /etc/fstab
								fi

								# Configurar el orden de montura de los FileSystem:
								if [[ ${!lvOrderMount} = "yes" ]]; then
									# Si es el primero, establece la configuración normal
									if [[ ${lvCount} -eq 1 ]]; then

										if [[ ${!lvMountAfter} ]]; then
											echo "/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults,x-systemd.requires-mounts-for=${!lvMountAfter}   0 0" >> /etc/fstab
										else
											echo "/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults   0 0" >> /etc/fstab
										fi
									else
										echo "/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults,x-systemd.requires-mounts-for=$requireMount   0 0" >> /etc/fstab
									fi
								else
									echo "/dev/${!vgName}/${!lvName}  ${!lvMountPoint}  $lvfileSystem   defaults   0 0" >> /etc/fstab
								fi
							fi

							requireMount=${!lvMountPoint}
							echo "${green}(i) Montando el File system.${reset}"
							mount ${!lvMountPoint} 

						else
							echo "${green}(i) Montando el directorio ${!lvMountPoint} sobre el LV /dev/${!vgName}/${!lvName} ${reset}"
							mount /dev/${!vgName}/${!lvName} ${!lvMountPoint} 
						fi

					fi
				fi

			else
				break
			fi

			((lvCount+=1))
		done
	else
		echo "${red}(X) No se indicó un nombre de vg en la configuración ${VG} del archivo yaml proporcionado. Verifique el parámetro ''name''${reset}"
		exit 1
	fi

done

echo -e "\n\n"
echo "${green}(i) Proceso terminado.${reset}"
echo -e "\n\n"

echo "${green}(i) Tomando evidencias posteriores del estado actual del storage en este servidor...${reset}"
sleep 2
echo "" > LVM_composer_after_$toDay_$toHour.out
echo "${green}(i) Dispositivos de bloque en este servidor ($(hostname) - $toDay $HOUR): ${reset}" | tee -a LVM_composer_after_$toDay_$toHour.out
lsblk -l | tee -a LVM_composer_after_$toDay_$toHour.out
echo "-------------------------------------------------" | tee -a LVM_composer_after_$toDay_$toHour.out
lsblk | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out 
echo "${green}(i) Physical volumes en este servidor después de terminar el proceso:${reset}"
pvdisplay | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Volumen Groups en este servidor después de terminar el proceso:${reset}"
vgdisplay | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Logical volumes en este servidor después de terminar el proceso:${reset}"
lvdisplay | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Estructura del File System de este servidor:${reset}"
df -hT | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n" | tee -a LVM_composer_before_$toDay_$toHour.out
echo "${green}(i) Contenido del archivo /etc/fstab:${reset}"
cat /etc/fstab | tee -a LVM_composer_after_$toDay_$toHour.out

echo -e "\n\n\n\n"
echo "${green}(i) Se dejaron las evidencias del estado actual del storage de este servidor en el archivo: LVM_composer_after_$toDay_$toHour.out${reset}"
echo -e "\n\n\n\n"
sleep 1

echo "${reset}"

# Próximamente:
#for LV in $(grep -Ew 'LV[0-9]{1,6}:' $1 | grep -Eo 'LV[0-9]{1,6}'); do
#	echo "Hacer algo con este Logical Volume: $LV"
#done
