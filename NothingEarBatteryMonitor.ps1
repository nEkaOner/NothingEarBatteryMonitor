# Script PowerShell pour créer un lanceur invisible
$monitorScript = @'
# Ajouter les assemblies nécessaires
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Régler la variable globale pour le chemin de l'icône
$global:IconPath = "$env:TEMP\system_icon.ico"
$global:DisplayMode = "graphic" # Valeurs possibles: "graphic" ou "text"
$global:LastBatteryLevel = -1 # -1 indique que les écouteurs n'ont jamais été détectés
$global:ErrorActionPreference = 'SilentlyContinue'

# Fonction pour récupérer le niveau de batterie
function Get-BluetoothBatteryLevel {
    $BTDeviceFriendlyName = "Nothing Ear (a)"
    $BTHDevices = Get-PnpDevice -FriendlyName "*$($BTDeviceFriendlyName)*" -ErrorAction SilentlyContinue

    if ($BTHDevices) {
        # Vérifier le statut de l'appareil d'abord
        foreach ($Device in $BTHDevices) {
            if ($Device.Status -eq "Unknown") {
                # Si le statut est "Unknown", retourner -1 pour traiter comme non détecté
                return -1
            }
        }
        
        # Si l'appareil n'est pas en statut "Unknown", vérifier la connexion et le niveau de batterie
        $isConnected = $false
        $BatteryLevels = foreach ($Device in $BTHDevices) {
            $BatteryProperty = Get-PnpDeviceProperty -InstanceId $Device.InstanceId -KeyName '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2' -ErrorAction SilentlyContinue |
                Where-Object { $_.Type -ne 'Empty' } |
                Select-Object -ExpandProperty Data -ErrorAction SilentlyContinue
            if ($null -ne $BatteryProperty) {
                $isConnected = $true
                $BatteryProperty
            }
        }
        
        if ($isConnected) {
            $global:LastBatteryLevel = $BatteryLevels[0]
            return $BatteryLevels[0]
        } else {
            # L'appareil est couplé mais pas connecté ou dans un autre état
            return -1  # Traiter comme non détecté
        }
    }
    return -1 # Retourne -1 pour indiquer que les écouteurs ne sont pas détectés du tout
}

# Fonction pour déterminer la couleur en fonction du niveau de batterie
function Get-BatteryColor {
    param (
        [int]$BatteryLevel
    )
    
    if ($BatteryLevel -eq -1) {
        return "non détecté"
    } elseif ($BatteryLevel -ge 75) {
        return "vert"
    } elseif ($BatteryLevel -ge 50) {
        return "jaune"
    } elseif ($BatteryLevel -ge 25) {
        return "orange"
    } else {
        return "rouge"
    }
}

# Fonction pour créer une icône avec texte du pourcentage
function New-TextPercentageIcon {
    param (
        [int]$BatteryLevel
    )
    
    # Couleur blanche pour le texte
    $textColor = [System.Drawing.Color]::White
    
    # Créer une nouvelle image 24x24 avec transparence
    $bitmap = New-Object System.Drawing.Bitmap 24, 24
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    try {
        # Effacer l'arrière-plan en transparent
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        if ($BatteryLevel -eq -1) {
            # Afficher un point d'interrogation pour les écouteurs non détectés ou en statut Unknown
            $displayText = "?"
        } else {
            # Déterminer le texte à afficher (sans le signe %)
            $displayText = [string]::Format("{0}", [Math]::Min(99, $BatteryLevel))
        }
        
        # Démarrer avec une taille de police relativement grande
        $fontSize = 15 # Augmenté pour l'icône plus grande
        $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
        
        # Mesurer la taille du texte
        $textSize = $graphics.MeasureString($displayText, $font)
        
        # Réduire la taille de la police si le texte dépasse l'espace (en laissant une marge de 3 pixels)
        while (($textSize.Width > 21) -or ($textSize.Height > 21)) {
            $fontSize -= 0.5
            $font.Dispose()
            $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
            $textSize = $graphics.MeasureString($displayText, $font)
        }
        
        # Centrer le texte dans l'icône
        $x = (24 - $textSize.Width) / 2
        $y = (24 - $textSize.Height) / 2
        
        # Dessiner le texte en blanc
        $textBrush = New-Object System.Drawing.SolidBrush ($textColor)
        $graphics.DrawString($displayText, $font, $textBrush, $x, $y)
        
        $textBrush.Dispose()
        $font.Dispose()
    }
    catch {
        # En cas d'erreur, remplir l'icône d'un simple fond blanc
        $simpleBrush = New-Object System.Drawing.SolidBrush ($textColor)
        $graphics.FillRectangle($simpleBrush, 0, 0, 24, 24)
        $simpleBrush.Dispose()
    }
    finally {
        $graphics.Dispose()
    }
    
    # Convertir le bitmap en icône
    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    
    return $icon
}

# Fonction pour créer une icône de texte par défaut
function CreateDefaultTextIcon {
    param (
        [System.Drawing.Graphics]$Graphics,
        [int]$BatteryLevel,
        [System.Drawing.Color]$TextColor
    )
    
    # Fond gris clair
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::LightGray)
    $Graphics.FillRectangle($bgBrush, 0, 0, 24, 24)
    $bgBrush.Dispose()
    
    # Bordure
    $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::DarkGray, 1)
    $Graphics.DrawRectangle($borderPen, 0, 0, 23, 23)
    $borderPen.Dispose()
    
    # Texte du pourcentage
    $font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush ($TextColor)
    
    # Déterminer le texte à afficher
    if ($BatteryLevel -eq -1) {
        $percentText = "?"
    } else {
        $percentText = [string]::Format("{0}", [Math]::Min(99, $BatteryLevel))
    }
    
    # Centrer le texte
    $textSize = $Graphics.MeasureString($percentText, $font)
    $x = (24 - $textSize.Width) / 2
    $y = (24 - $textSize.Height) / 2
    
    $Graphics.DrawString($percentText, $font, $textBrush, $x, $y)
    
    $textBrush.Dispose()
    $font.Dispose()
}

# Fonction pour créer une icône de batterie avec point de couleur
function New-BatteryIcon {
    param (
        [int]$BatteryLevel
    )
    
    # Déterminer la couleur en fonction du niveau de batterie
    $dotColor = if ($BatteryLevel -eq -1) {
        [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gris pour non détecté ou Unknown (au lieu de rouge)
    } elseif ($BatteryLevel -ge 75) {
        [System.Drawing.Color]::FromArgb(0, 180, 0)    # Vert
    } elseif ($BatteryLevel -ge 50) {
        [System.Drawing.Color]::FromArgb(220, 180, 0)  # Jaune
    } elseif ($BatteryLevel -ge 25) {
        [System.Drawing.Color]::FromArgb(255, 128, 0)  # Orange
    } else {
        [System.Drawing.Color]::FromArgb(200, 0, 0)    # Rouge
    }
    
    # Créer une nouvelle image avec transparence
    $bitmap = New-Object System.Drawing.Bitmap 24, 24
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    try {
        # Effacer l'arrière-plan (transparent)
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        # Vérifier si l'icône personnalisée existe
        if (Test-Path $global:IconPath) {
            try {
                # Tenter de charger l'icône depuis le fichier
                $baseIcon = New-Object System.Drawing.Icon($global:IconPath)
                # Dessiner l'icône entière
                $graphics.DrawIcon($baseIcon, 0, 0)
                $baseIcon.Dispose()
                
                # Position et taille du cercle
                $circleX = 12
                $circleY = 12
                $circleSize = 11 # Taille du cercle
                
                # Dessiner un point de couleur (même pour non détecté, pas de croix)
                $dotBrush = New-Object System.Drawing.SolidBrush ($dotColor)
                $graphics.FillEllipse($dotBrush, $circleX, $circleY, $circleSize, $circleSize)
                $dotBrush.Dispose()
            }
            catch {
                Write-Host "Erreur lors du chargement de l'icône: $_"
                # Si le chargement échoue, créer une icône de batterie par défaut
                CreateDefaultBatteryIcon -Graphics $graphics -BatteryLevel $BatteryLevel -DotColor $dotColor
            }
        }
        else {
            # Créer une icône de batterie par défaut
            CreateDefaultBatteryIcon -Graphics $graphics -BatteryLevel $BatteryLevel -DotColor $dotColor
        }
    }
    catch {
        Write-Host "Erreur générale dans New-BatteryIcon: $_"
        # En cas d'erreur, dessiner une icône très simple
        $simpleBrush = New-Object System.Drawing.SolidBrush ($dotColor)
        $graphics.FillEllipse($simpleBrush, 0, 0, 24, 24)
        $simpleBrush.Dispose()
    }
    finally {
        # Libérer les ressources
        $graphics.Dispose()
    }
    
    # Convertir le bitmap en icône
    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    
    return $icon
}

# Fonction auxiliaire pour créer l'icône de batterie par défaut
function CreateDefaultBatteryIcon {
    param (
        [System.Drawing.Graphics]$Graphics,
        [int]$BatteryLevel,
        [System.Drawing.Color]$DotColor
    )
    
    # Dessiner une icône de batterie par défaut
    $batteryColor = [System.Drawing.Color]::LightGray
    $batteryBrush = New-Object System.Drawing.SolidBrush ($batteryColor)
    $batteryPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::DarkGray, 1)
    
    # Corps de la batterie - adaptée pour 24x24
    $Graphics.FillRectangle($batteryBrush, 3, 5, 15, 14)
    $Graphics.DrawRectangle($batteryPen, 3, 5, 15, 14)
    
    # Terminaison de la batterie
    $Graphics.FillRectangle($batteryBrush, 18, 8, 3, 8)
    $Graphics.DrawRectangle($batteryPen, 18, 8, 3, 8)
    
    if ($BatteryLevel -eq -1) {
        # Au lieu de la croix rouge, utiliser un gris clair pour indiquer batterie non détectée
        $emptyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 200, 200))
        $Graphics.FillRectangle($emptyBrush, 4, 6, 13, 12)
        $emptyBrush.Dispose()
    } else {
        # Niveau de la batterie
        $fillHeight = [Math]::Max(1, [Math]::Round(12 * $BatteryLevel / 100))
        $fillRect = New-Object System.Drawing.Rectangle(4, 18 - $fillHeight, 13, $fillHeight)
        $fillBrush = New-Object System.Drawing.SolidBrush ($DotColor)
        $Graphics.FillRectangle($fillBrush, $fillRect)
        $fillBrush.Dispose()
    }
    
    $batteryBrush.Dispose()
    $batteryPen.Dispose()
}

# Créer une application Windows Forms
$form = New-Object System.Windows.Forms.Form
$form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
$form.ShowInTaskbar = $false
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.Size = New-Object System.Drawing.Size 0, 0

# Créer l'icône de la barre système
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Text = "Nothing Ear (a)"
$notifyIcon.Visible = $true

# Créer le menu contextuel
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Menu Mode d'affichage - Graphique
$graphicModeMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$graphicModeMenuItem.Text = "Version graphique"
$graphicModeMenuItem.Checked = ($global:DisplayMode -eq "graphic")
$graphicModeMenuItem.Add_Click({
    $global:DisplayMode = "graphic"
    $graphicModeMenuItem.Checked = $true
    $textModeMenuItem.Checked = $false
    Update-BatteryIcon
})

# Menu Mode d'affichage - Texte
$textModeMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$textModeMenuItem.Text = "Version texte"
$textModeMenuItem.Checked = ($global:DisplayMode -eq "text")
$textModeMenuItem.Add_Click({
    $global:DisplayMode = "text"
    $textModeMenuItem.Checked = $true
    $graphicModeMenuItem.Checked = $false
    Update-BatteryIcon
})

# Menu Actualiser
$refreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshMenuItem.Text = "Actualiser"
$refreshMenuItem.Add_Click({
    Update-BatteryIcon
})

# Menu Quitter
$exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitMenuItem.Text = "Quitter"
$exitMenuItem.Add_Click({
    $notifyIcon.Visible = $false
    $timer.Stop()
    $timer.Dispose()
    $form.Close()
    [System.Windows.Forms.Application]::Exit()
})

# Ajout d'un séparateur
$separator1 = New-Object System.Windows.Forms.ToolStripSeparator
$separator2 = New-Object System.Windows.Forms.ToolStripSeparator

# Ajouter les menus au menu contextuel
$contextMenu.Items.Add($graphicModeMenuItem)
$contextMenu.Items.Add($textModeMenuItem)
$contextMenu.Items.Add($separator1)
$contextMenu.Items.Add($refreshMenuItem)
$contextMenu.Items.Add($separator2)
$contextMenu.Items.Add($exitMenuItem)
$notifyIcon.ContextMenuStrip = $contextMenu

# Fonction pour mettre à jour l'icône
function Update-BatteryIcon {
    $batteryLevel = Get-BluetoothBatteryLevel
    
    # Message d'état pour l'infobulle
    if ($batteryLevel -eq -1) {
        $statusText = "Nothing Ear (a)"
    } else {
        $statusText = "Nothing Ear (a) - $batteryLevel%"
    }
    
    # Mettre à jour le texte
    $notifyIcon.Text = $statusText
    
    try {
        # Obtenir l'icône selon le mode d'affichage sélectionné
        $icon = if ($global:DisplayMode -eq "text") {
            New-TextPercentageIcon -BatteryLevel $batteryLevel
        } else {
            New-BatteryIcon -BatteryLevel $batteryLevel
        }
        
        if ($icon -ne $null) {
            $notifyIcon.Icon = $icon
        }
    }
    catch {
        Write-Host "Erreur lors de la mise à jour de l'icône: $_"
    }
}

# Définir un timer pour mettre à jour l'icône toutes les 5 minutes
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300000  # 5 minutes en millisecondes
$timer.Add_Tick({ Update-BatteryIcon })
$timer.Start()

# Mettre à jour l'icône au démarrage
Update-BatteryIcon

# Ajout d'une interaction au double-clic sur l'icône
$notifyIcon.Add_MouseDoubleClick({
    Update-BatteryIcon
    $batteryLevel = Get-BluetoothBatteryLevel
    
    if ($batteryLevel -eq -1) {
        $message = "Nothing Ear (a) - Non détecté ou Unknown"
        if ($global:LastBatteryLevel -ge 0) {
            $message += "`nDernier niveau connu: $global:LastBatteryLevel%"
        }
    } else {
        $message = "Nothing Ear (a) - $batteryLevel%"
    }
    
    # Utilisation de "Etat" sans accent pour éviter les problèmes d'affichage
    [System.Windows.Forms.MessageBox]::Show($message, "Etat de la batterie", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

# Démarrer l'application sans sortie
[System.Windows.Forms.Application]::Run($form)
'@

# Déterminer le chemin vers le dossier de script actuel
$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Vérifier si l'icône existe et avertir l'utilisateur si elle ne l'est pas
$iconPath = Join-Path -Path $currentDir -ChildPath "system_icon.ico"
if (-not (Test-Path $iconPath)) {
    Write-Output "ATTENTION: Le fichier 'system_icon.ico' n'a pas été trouvé dans le dossier: $currentDir"
    Write-Output "Utilisation d'une icône générée dynamiquement à la place."
} else {
    # Vérifier que l'icône est valide
    try {
        [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
        Write-Output "L'icône 'system_icon.ico' a été validée avec succès."
    } catch {
        Write-Output "ATTENTION: Le fichier 'system_icon.ico' existe mais n'est pas une icône valide ou est endommagé."
        Write-Output "Utilisation d'une icône générée dynamiquement à la place."
    }
}

# Rediriger toute sortie non gérée vers null pour éviter la création de fichiers indésirables
$ErrorActionPreference = 'SilentlyContinue'

# Créer un fichier temporaire pour le script principal
$scriptPath = "$env:TEMP\BatteryMonitor.ps1"
$monitorScript | Out-File -FilePath $scriptPath -Encoding utf8 -NoNewline

# Copier l'icône vers le dossier temporaire si elle existe
if (Test-Path $iconPath) {
    Copy-Item -Path $iconPath -Destination "$env:TEMP\system_icon.ico" -Force
    Write-Output "L'icône 'system_icon.ico' a été copiée vers le dossier temporaire: $env:TEMP\system_icon.ico"
    
    # Vérification supplémentaire après copie
    if (Test-Path "$env:TEMP\system_icon.ico") {
        Write-Output "Confirmation : L'icône a bien été copiée dans le dossier temporaire."
    } else {
        Write-Output "ERREUR : La copie de l'icône vers le dossier temporaire a échoué."
    }
}

# Créer et exécuter un processus PowerShell caché
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell.exe"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$psi.CreateNoWindow = $true
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true  # Rediriger la sortie standard pour éviter les fichiers indésirables

# Démarrer le processus
$process = [System.Diagnostics.Process]::Start($psi)

Write-Output "Le moniteur de batterie a été démarré en arrière-plan."
if (Test-Path $iconPath) {
    Write-Output "L'icône 'system_icon.ico' est utilisée comme base avec un indicateur de batterie."
} else {
    Write-Output "Une icône de batterie est générée dynamiquement."
}
Write-Output "L'indicateur change de couleur selon le niveau de batterie:"
Write-Output "- 75-100% : vert"
Write-Output "- 50-74% : jaune" 
Write-Output "- 25-49% : orange"
Write-Output "- 0-24% : rouge"
Write-Output "- Non détecté ou statut Unknown : point gris (mode graphique) / ? (mode texte)"
Write-Output "L'infobulle affiche maintenant : 'Nothing Ear (a) - XX%' ou 'Nothing Ear (a) - Non détecté'"
Write-Output "Deux modes d'affichage sont disponibles dans le menu contextuel :"
Write-Output "- Version graphique : affiche un point de couleur selon le niveau de batterie"
Write-Output "- Version texte : affiche le pourcentage de batterie ou ? si non détecté/Unknown"
Write-Output "Pour le fermer, cliquez-droit sur l'icône dans la barre des tâches et sélectionnez 'Quitter'."