#!/bin/bash
# shellcheck disable=SC2001,SC1111,SC1112,SC2143,SC2145,SC2086,SC2089,SC2090

####################################################################################################
#
# Setup Your Mac via swiftDialog
# https://snelson.us/sym
#
####################################################################################################
#
# HISTORY
#
#   Version 1.13.0, 24-Oct-2023, Dan K. Snelson (@dan-snelson)
#   - 🔥 **Breaking Change** for users of Setup Your Mac prior to `1.13.0` 🔥
#       - Removed `setupYourMacPolicyArrayIconPrefixUrl` (in favor using the fully qualified domain name of the server which hosts your icons)
#   - Added [SYM-Helper] to identify variables which can be configured in SYM-Helper (0.8.0)
#   - Updated sample banner image (Image by pikisuperstar on Freepik)
#   - Added `overlayoverride` variable to dynamically override the `overlayicon`, based on which Configuration is selected by the end-user ([Pull Request No. 111](https://github.com/dan-snelson/Setup-Your-Mac/pull/111); thanks yet again, @drtaru!)
#   - Modified the display of support-related information (including adding `supportTeamWebsite` (Addresses [Issue No. 97](https://github.com/dan-snelson/Setup-Your-Mac/issues/97); thanks, @theahadub!))
#   - Adjustments to Completion Actions (including the `wait` flavor; thanks for the heads-up, @Tom!)
#   - Updated Microsoft Teams filepath validation
#   - Add position prompt (Addresses [Issue No. 120](https://github.com/dan-snelson/Setup-Your-Mac/issues/120); thanks for the suggestion, @astrugatch! [Pull Request No. 121](https://github.com/dan-snelson/Setup-Your-Mac/pull/121); thanks, @drtaru! This has to be your best one yet!)
#   - Corrections to "Continue" button after Network Quality test [Pull Request No. 115](https://github.com/dan-snelson/Setup-Your-Mac/pull/115); thanks, @delize!
#
####################################################################################################

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version and Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.13.0-4"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
scriptLog="${4:-"/var/log/org.churchofjesuschrist.log"}"                    # Parameter 4: Script Log Location [ /var/log/org.churchofjesuschrist.log ] (i.e., Your organization's default location for client-side logs)
debugMode="${5:-"verbose"}"                                                 # Parameter 5: Debug Mode [ verbose (default) | true | false ]
welcomeDialog="${6:-"userInput"}"                                           # Parameter 6: Welcome dialog [ userInput ]
completionActionOption="${7:-"Restart Attended"}"                           # Parameter 7: Completion Action [ wait | sleep (with seconds) | Shut Down | Shut Down Attended | Shut Down Confirm | Restart | Restart Attended (default) | Restart Confirm | Log Out | Log Out Attended | Log Out Confirm ]
requiredMinimumBuild="${8:-"disabled"}"                                     # Parameter 8: Required Minimum Build [ disabled (default) | 22E ] (i.e., Your organization's required minimum build of macOS to allow users to proceed; use "22E" for macOS 13.3)
outdatedOsAction="${9:-"/System/Library/CoreServices/Software Update.app"}" # Parameter 9: Outdated OS Action [ /System/Library/CoreServices/Software Update.app (default) | jamfselfservice://content?entity=policy&id=117&action=view ] (i.e., Jamf Pro Self Service policy ID for operating system ugprades)
webhookURL="${10:-""}"                                                      # Parameter 10: Microsoft Teams or Slack Webhook URL [ Leave blank to disable (default) | https://microsoftTeams.webhook.com/URL | https://hooks.slack.com/services/URL ] Can be used to send a success or failure message to Microsoft Teams or Slack via Webhook. (Function will automatically detect if Webhook URL is for Slack or Teams; can be modified to include other communication tools that support functionality.)
presetConfiguration="${11:-""}"                                             # Parameter 11: Specify a Configuration (i.e., `policyJSON`; NOTE: If set, `promptForConfiguration` will be automatically suppressed and the preselected configuration will be used instead)
swiftDialogMinimumRequiredVersion="2.3.2.4726"                              # This will be set and updated as dependancies on newer features change.

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Various Feature Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

debugModeSleepAmount="3" # Delay for various actions when running in Debug Mode
failureDialog="true"     # Display the so-called "Failure" dialog (after the main SYM dialog) [ true | false ]

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Message User Input Customization Choices (thanks, @rougegoat!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# [SYM-Helper] These control which user input boxes are added to the first page of Setup Your Mac. If you do not want to ask about a value, set it to any other value
promptForUsername="true"
prefillUsername="false" # prefills the currently logged in user's username
promptForRealName="false"
prefillRealname="false" # prefills the currently logged in user's fullname
promptForEmail="false"
promptForComputerName="false"
promptForAssetTag="true"
promptForRoom="false"
promptForBuilding="true"
promptForDepartment="true"
promptForPosition="false"      # When set to true dynamically prompts the user to select from a list of positions or manually enter one at the welcomeDialog, see "positionListRaw" to define the selection / entry type
promptForConfiguration="false" # Removes the Configuration dropdown entirely and uses the "Catch-all (i.e., used when `welcomeDialog` is set to `video` or `false`)" or presetConfiguration policyJSON

# Set to "true" to suppress the Update Inventory option on policies that are called
suppressReconOnPolicy="false"

# Disables the Blurscreen enabled by default in Production
moveableInProduction="true"

# [SYM-Helper] An unsorted, comma-separated list of buildings (with possible duplication). If empty, this will be hidden from the user info prompt
buildingsListRaw="Minimbah,Penbank,Senior Campus"

# A sorted, unique, JSON-compatible list of buildings
buildingsList=$(echo "${buildingsListRaw}" | tr ',' '\n' | sort -f | uniq | sed -e 's/^/\"/' -e 's/$/\",/' -e '$ s/.$//')

# [SYM-Helper] An unsorted, comma-separated list of departments (with possible duplication). If empty, this will be hidden from the user info prompt
departmentListRaw="Student,Staff,Class"

# A sorted, unique, JSON-compatible list of departments
departmentList=$(echo "${departmentListRaw}" | tr ',' '\n' | sort -f | uniq | sed -e 's/^/\"/' -e 's/$/\",/' -e '$ s/.$//')

# An unsorted, comma-separated list of departments (with possible duplication). If empty and promptForPosition is "true" a user-input box will be shown instead of a dropdown
positionListRaw="Developer,Management,Sales,Marketing"

# A sorted, unique, JSON-compatible list of positions
positionList=$(echo "${positionListRaw}" | tr ',' '\n' | sort -f | uniq | sed -e 's/^/\"/' -e 's/$/\",/' -e '$ s/.$//')

# [SYM-Helper] Branding overrides
brandingBanner="" # Image by pikisuperstar on Freepik
brandingBannerDisplayText="false"
brandingIconLight="https://avatars.githubusercontent.com/u/112675474"
brandingIconDark="https://avatars.githubusercontent.com/u/112675474"

# [SYM-Helper] IT Support Variables - Use these if the default text is fine but you want your org's info inserted instead
supportTeamName="Woodleigh HelpDesk"
supportTeamPhone=""
supportTeamEmail="helpdesk@woodleigh.vic.edu.au"
supportTeamWebsite="https://servicedesk.woodleigh.vic.edu.au/"
supportTeamHyperlink="[${supportTeamWebsite}](https://${supportTeamWebsite})"
supportKB=""
supportTeamErrorKB=""

# Disable the "Continue" button in the User Input "Welcome" dialog until Dynamic Download Estimates have complete [ true | false ] (thanks, @Eltord!)
lockContinueBeforeEstimations="true"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System, Computer Model Name, etc.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$(sw_vers -productVersion)
osVersionExtra=$(sw_vers -productVersionExtra)
osBuild=$(sw_vers -buildVersion)
osMajorVersion=$(echo "${osVersion}" | awk -F '.' '{print $1}')
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi # Report RSR sub version if applicable
reconOptions=""
exitCode="0"

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
	touch "${scriptLog}"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
	echo -e "$(date +%Y-%m-%d\ %H:%M:%S) - ${1}" | tee -a "${scriptLog}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Current Logged-in User Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function currentLoggedInUser() {
	loggedInUser=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }')
	updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User: ${loggedInUser}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# Setup Your Mac (${scriptVersion})\n# https://snelson.us/sym\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running under bash
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "$BASH" != "/bin/bash" ]]; then
	updateScriptLog "PRE-FLIGHT CHECK: This script must be run under 'bash', please do not run it using 'sh', 'zsh', etc.; exiting."
	exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
	updateScriptLog "PRE-FLIGHT CHECK: This script must be run as root; exiting."
	exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Setup Assistant has completed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

while pgrep -q -x "Setup Assistant"; do
	updateScriptLog "PRE-FLIGHT CHECK: Setup Assistant is still running; pausing for 2 seconds"
	sleep 2
done

updateScriptLog "PRE-FLIGHT CHECK: Setup Assistant is no longer running; proceeding …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm Dock is running / user is at Desktop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

until pgrep -q -x "Finder" && pgrep -q -x "Dock"; do
	updateScriptLog "PRE-FLIGHT CHECK: Finder & Dock are NOT running; pausing for 1 second"
	sleep 1
done

updateScriptLog "PRE-FLIGHT CHECK: Finder & Dock are running; proceeding …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Logged-in System Accounts
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Check for Logged-in System Accounts …"
currentLoggedInUser

counter="1"

until { [[ "${loggedInUser}" != "_mbsetupuser" ]] || [[ "${counter}" -gt "180" ]]; } && { [[ "${loggedInUser}" != "loginwindow" ]] || [[ "${counter}" -gt "30" ]]; }; do

	updateScriptLog "PRE-FLIGHT CHECK: Logged-in User Counter: ${counter}"
	currentLoggedInUser
	sleep 2
	((counter++))

done

loggedInUserFullname=$(id -F "${loggedInUser}")
loggedInUserFirstname=$(echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}')
loggedInUserID=$(id -u "${loggedInUser}")
updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User First Name: ${loggedInUserFirstname}"
updateScriptLog "PRE-FLIGHT CHECK: Current Logged-in User ID: ${loggedInUserID}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate Operating System Version and Build
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${requiredMinimumBuild}" == "disabled" ]]; then

	updateScriptLog "PRE-FLIGHT CHECK: 'requiredMinimumBuild' has been set to ${requiredMinimumBuild}; skipping OS validation."
	updateScriptLog "PRE-FLIGHT CHECK: macOS ${osVersion} (${osBuild}) installed"

else

	# Since swiftDialog requires at least macOS 12 Monterey, first confirm the major OS version
	if [[ "${osMajorVersion}" -ge 12 ]]; then

		updateScriptLog "PRE-FLIGHT CHECK: macOS ${osMajorVersion} installed; checking build version ..."

		# Confirm the Mac is running `requiredMinimumBuild` (or later)
		if [[ "${osBuild}" > "${requiredMinimumBuild}" ]]; then

			updateScriptLog "PRE-FLIGHT CHECK: macOS ${osVersion} (${osBuild}) installed; proceeding ..."

		# When the current `osBuild` is older than `requiredMinimumBuild`; exit with error
		else
			updateScriptLog "PRE-FLIGHT CHECK: The installed operating system, macOS ${osVersion} (${osBuild}), needs to be updated to Build ${requiredMinimumBuild}; exiting with error."
			osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\rExpected macOS Build '${requiredMinimumBuild}' (or newer), but found macOS '${osVersion}' ('${osBuild}').\r\r" with title "Setup Your Mac: Detected Outdated Operating System" buttons {"Open Software Update"} with icon caution'
			updateScriptLog "PRE-FLIGHT CHECK: Executing open '${outdatedOsAction}' …"
			su - "${loggedInUser}" -c "open \"${outdatedOsAction}\""
			exit 1

		fi

	# The Mac is running an operating system older than macOS 12 Monterey; exit with error
	else

		updateScriptLog "PRE-FLIGHT CHECK: swiftDialog requires at least macOS 12 Monterey and this Mac is running ${osVersion} (${osBuild}), exiting with error."
		osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\rExpected macOS Build '${requiredMinimumBuild}' (or newer), but found macOS '${osVersion}' ('${osBuild}').\r\r" with title "Setup Your Mac: Detected Outdated Operating System" buttons {"Open Software Update"} with icon caution'
		updateScriptLog "PRE-FLIGHT CHECK: Executing open '${outdatedOsAction}' …"
		su - "${loggedInUser}" -c "open \"${outdatedOsAction}\""
		exit 1

	fi

fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Ensure computer does not go to sleep during SYM (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

symPID="$$"
updateScriptLog "PRE-FLIGHT CHECK: Caffeinating this script (PID: $symPID)"
caffeinate -dimsu -w $symPID &

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Toggle `jamf` binary check-in (thanks, @robjschroeder!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function toggleJamfLaunchDaemon() {

	jamflaunchDaemon="/Library/LaunchDaemons/com.jamfsoftware.task.1.plist"

	if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then

		if [[ $(/bin/launchctl list | grep com.jamfsoftware.task.E) ]]; then
			updateScriptLog "PRE-FLIGHT CHECK: DEBUG MODE: Normally, 'jamf' binary check-in would be temporarily disabled"
		else
			updateScriptLog "QUIT SCRIPT: DEBUG MODE: Normally, 'jamf' binary check-in would be re-enabled"
		fi

	else

		while [[ ! -f "${jamflaunchDaemon}" ]]; do
			updateScriptLog "PRE-FLIGHT CHECK: Waiting for installation of ${jamflaunchDaemon}"
			sleep 0.1
		done

		if [[ $(/bin/launchctl list | grep com.jamfsoftware.task.E) ]]; then

			updateScriptLog "PRE-FLIGHT CHECK: Temporarily disable 'jamf' binary check-in"
			/bin/launchctl bootout system "${jamflaunchDaemon}"

		else

			updateScriptLog "QUIT SCRIPT: Re-enabling 'jamf' binary check-in"
			updateScriptLog "QUIT SCRIPT: 'jamf' binary check-in daemon not loaded, attempting to bootstrap and start"
			result="0"

			until [ $result -eq 3 ]; do

				/bin/launchctl bootstrap system "${jamflaunchDaemon}" && /bin/launchctl start "${jamflaunchDaemon}"
				result="$?"

				if [ $result = 3 ]; then
					updateScriptLog "QUIT SCRIPT: Staring 'jamf' binary check-in daemon"
				else
					updateScriptLog "QUIT SCRIPT: Failed to start 'jamf' binary check-in daemon"
				fi

			done

		fi

	fi

}

toggleJamfLaunchDaemon

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate `supportTeam` variables are populated
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z $supportTeamName ]]; then
	updateScriptLog "PRE-FLIGHT CHECK: 'supportTeamName' must be populated to proceed; exiting"
	exit 1
fi

if [[ -z $supportTeamPhone && -z $supportTeamEmail && -z $supportKB ]]; then
	updateScriptLog "PRE-FLIGHT CHECK: At least ONE 'supportTeam' variable must be populated to proceed; exiting"
	exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "PRE-FLIGHT CHECK: Complete"

####################################################################################################
#
# Dialog Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# infobox-related variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

macOSproductVersion="$(sw_vers -productVersion)"
macOSbuildVersion="$(sw_vers -buildVersion)"
serialNumber=$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}')
timestamp="$(date '+%Y-%m-%d-%H%M%S')"
dialogVersion=$(/usr/local/bin/dialog --version)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Reflect Debug Mode in `infotext` (i.e., bottom, left-hand corner of each dialog)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case ${debugMode} in
"true") scriptVersion="DEBUG MODE | Dialog: v${dialogVersion} • Setup Your Mac: v${scriptVersion}" ;;
"verbose") scriptVersion="VERBOSE DEBUG MODE | Dialog: v${dialogVersion} • Setup Your Mac: v${scriptVersion}" ;;
esac

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set JAMF binary, Dialog path and Command Files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

jamfBinary="/usr/local/bin/jamf"
dialogBinary="/usr/local/bin/dialog"
welcomeJSONFile=$(mktemp -u /var/tmp/welcomeJSONFile.XXX)
welcomeCommandFile=$(mktemp -u /var/tmp/dialogCommandFileWelcome.XXX)
setupYourMacCommandFile=$(mktemp -u /var/tmp/dialogCommandFileSetupYourMac.XXX)
failureCommandFile=$(mktemp -u /var/tmp/dialogCommandFileFailure.XXX)

####################################################################################################
#
# Welcome dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeMessage="Please enter the **required** information, then click **Continue** to start applying settings to your new Mac. \n\nOnce completed, the **Wait** button will be enabled and you‘ll be able to review the results before restarting."

if [[ -n "${supportTeamName}" ]]; then

	welcomeMessage+="\n\nIf you need assistance, please contact the **${supportTeamName}**:  \n"

	if [[ -n "${supportTeamPhone}" ]]; then
		welcomeMessage+="- **Telephone**: ${supportTeamPhone}\n"
	fi

	if [[ -n "${supportTeamEmail}" ]]; then
		welcomeMessage+="- **Email**: ${supportTeamEmail}\n"
	fi

	if [[ -n "${supportTeamWebsite}" ]]; then
		welcomeMessage+="- **Web**: ${supportTeamHyperlink}\n"
	fi

	if [[ -n "${supportKB}" ]]; then
		welcomeMessage+="- **Knowledge Base Article:** ${supportTeamErrorKB}\n"
	fi

fi

welcomeMessage+="\n\n---"

welcomeBannerText=""

# Cache the hosted custom welcomeBannerImage
if [[ $welcomeBannerImage == *"http"* ]]; then
	welcomeBannerImageFileName=$(echo ${welcomeBannerImage} | awk -F '/' '{print $NF}')
	updateScriptLog "WELCOME DIALOG: Auto-caching hosted '$welcomeBannerImageFileName' …"
	curl -L --location --silent "$welcomeBannerImage" -o "/var/tmp/${welcomeBannerImageFileName}"
	welcomeBannerImage="/var/tmp/${welcomeBannerImageFileName}"
fi

# Welcome icon set to either light or dark, based on user's Apperance setting (thanks, @mm2270!)
appleInterfaceStyle=$(defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1)
if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
	if [[ -n "$brandingIconDark" ]]; then
		welcomeIcon="$brandingIconDark"
	else welcomeIcon="https://cdn-icons-png.flaticon.com/512/740/740878.png"; fi
else
	if [[ -n "$brandingIconLight" ]]; then
		welcomeIcon="$brandingIconLight"
	else welcomeIcon="https://cdn-icons-png.flaticon.com/512/979/979585.png"; fi
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" JSON Conditionals (thanks, @rougegoat!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# prepopulate from UserInfo.plist (for re-runs)
if [ -f /Users/Shared/UserInfo.plist ]; then
	plistAssetTag=$(defaults read /Users/Shared/UserInfo.plist "Asset Tag" 2>/dev/null)
	plistCampus=$(defaults read /Users/Shared/UserInfo.plist "Campus" 2>/dev/null)
	plistPosition=$(defaults read /Users/Shared/UserInfo.plist "Position" 2>/dev/null)
	plistUsername=$(defaults read /Users/Shared/UserInfo.plist "Username" 2>/dev/null)
fi
if [ -n "$plistAssetTag" ]; then
	assetTagPrefil='"value" : "'${plistAssetTag}'",'
fi
if [ -n "$plistCampus" ]; then
	campusPrefil="${plistCampus}"
fi
if [ -n "$plistPosition" ]; then
	positionPrefil="${plistPosition}"
fi
if [ -n "$plistUsername" ]; then
	usernamePrefil=',"value" : "'${plistUsername}'"'
fi

# Text Fields
if [ "$promptForUsername" == "true" ]; then
	usernameJSON='{ "title" : "Username",
		"required" : true,
		"prompt" : "Username"'${usernamePrefil}'},'
fi
if [ "$promptForAssetTag" == "true" ]; then
	assetTagJSON='{   "title" : "Asset Tag",
        "required" : true,
        "prompt" : "Please enter the asset tag",
		'${assetTagPrefil}'
        "regex" : "^[0-9]{4,}$",
        "regexerror" : "Invalid Asset Tag!"
    },'
fi

textFieldJSON="${usernameJSON}${assetTagJSON}"
textFieldJSON=$(echo ${textFieldJSON} | sed 's/,$//')

# Dropdowns
if [ "$promptForBuilding" == "true" ]; then
	if [ -n "$buildingsListRaw" ]; then
		buildingJSON='{
            "title" : "Campus",
            "default" : "'$campusPrefil'",
            "required" : true,
            "values" : [
                '${buildingsList}'
            ]
        },'
	fi
fi

if [ "$promptForDepartment" == "true" ]; then
	if [ -n "$departmentListRaw" ]; then
		departmentJSON='{
            "title" : "Position",
            "default" : "'$positionPrefil'",
            "required" : true,
            "values" : [
                '${departmentList}'
            ]
        },'
	fi
fi

selectItemsJSON="${buildingJSON}${departmentJSON}"
selectItemsJSON=$(echo $selectItemsJSON | sed 's/,$//')

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome" JSON for Capturing User Input (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeJSON='
{
    "commandfile" : "'"${welcomeCommandFile}"'",
    "bannertext" : "'"${welcomeBannerText}"'",
    "message" : "'"${welcomeMessage}"'",
    "icon" : "'"${welcomeIcon}"'",
    "infobox" : "Analyzing …",
    "iconsize" : "198.0",
    "button1text" : "Continue",
    "button2text" : "Quit",
    "infotext" : "'"${scriptVersion}"'",
    "blurscreen" : "true",
    "ontop" : "true",
    "titlefont" : "shadow=true, size=36, colour=#FFFDF4",
    "messagefont" : "size=14",
    "textfield" : [
        '${textFieldJSON}'
    ],
    "selectitems" : [
        '${selectItemsJSON}'
    ],
    "height" : "500"
}
'

####################################################################################################
#
# Setup Your Mac dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" dialog Title, Message, Icon and Overlay Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="<Setting up title>"
message="Please wait while your Mac is being configured..."

if [[ "${brandingBannerDisplayText}" == "true" ]]; then
	bannerText="<Setting up banner>"
else
	bannerText=""
fi

if [ -n "$supportTeamName" ]; then
	helpmessage+="If you need assistance, please contact:  \n\n**${supportTeamName}**  \n"
fi

if [ -n "$supportTeamPhone" ]; then
	helpmessage+="- **Telephone:** ${supportTeamPhone}  \n"
fi

if [ -n "$supportTeamEmail" ]; then
	helpmessage+="- **Email:** ${supportTeamEmail}  \n"
fi

if [ -n "$supportTeamWebsite" ]; then
	helpmessage+="- **Web**: ${supportTeamHyperlink}  \n"
fi

if [ -n "$supportKB" ]; then
	helpmessage+="- **Knowledge Base Article:** ${supportTeamErrorKB}  \n"
fi

helpmessage+="\n**Computer Information:**  \n"
helpmessage+="- **Operating System:** ${macOSproductVersion} (${macOSbuildVersion})  \n"
helpmessage+="- **Serial Number:** ${serialNumber}  \n"
helpmessage+="- **Dialog:** ${dialogVersion}  \n"
helpmessage+="- **Started:** ${timestamp}"

infobox="Analyzing input …" # Customize at "Update Setup Your Mac's infobox"

# Create `overlayicon` from Self Service's custom icon (thanks, @meschwartz!)
xxd -p -s 260 "$(defaults read /Library/Preferences/com.jamfsoftware.jamf self_service_app_path)"/Icon$'\r'/..namedfork/rsrc | xxd -r -p >/var/tmp/overlayicon.icns
overlayicon="/var/tmp/overlayicon.icns"

# Uncomment to use generic, Self Service icon as overlayicon
# overlayicon="https://ics.services.jamfcloud.com/icon/hash_aa63d5813d6ed4846b623ed82acdd1562779bf3716f2d432a8ee533bba8950ee"

# Set initial icon based on whether the Mac is a desktop or laptop
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
	icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
	icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSetupYourMacCMD="$dialogBinary \
--bannertext \"$bannerText\" \
--title \"$title\" \
--message \"$message\" \
--helpmessage \"$helpmessage\" \
--icon \"$icon\" \
--infobox \"${infobox}\" \
--progress \
--progresstext \"Initializing configuration …\" \
--button1text \"Wait\" \
--button1disabled \
--infotext \"$scriptVersion\" \
--titlefont 'shadow=true, size=36, colour=#FFFDF4' \
--messagefont 'size=14' \
--height '500' \
--position 'centre' \
--blurscreen \
--ontop \
--overlayicon \"$overlayicon\" \
--quitkey k \
--commandfile \"$setupYourMacCommandFile\" "

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# [SYM-Helper] "Setup Your Mac" policies to execute (Thanks, Obi-@smithjw!)
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://vimeo.com/772998915
# - progresstext: The text to be displayed below the progress bar
# - trigger: The Jamf Pro Policy Custom Event Name
# - validation: [ {absolute path} | Local | Remote | None | Recon ]
#   See: https://snelson.us/2023/01/setup-your-mac-validation/
#       - {absolute path} (simulates pre-v1.6.0 behavior, for example: "/Applications/Microsoft Teams classic.app/Contents/Info.plist")
#       - Local (for validation within this script, for example: "filevault")
#       - Remote (for validation via a single-script Jamf Pro policy, for example: "symvGlobalProtect")
#       - None (for triggers which don't require validation; always evaluates as successful)
#       - Recon (to update the computer's inventory with your Jamf Pro server)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Thanks, @wakco: If you would prefer to get your policyJSON externally replace it with:
#  - policyJSON="$(cat /path/to/file.json)" # For getting from a file, replacing /path/to/file.json with the path to your file, or
#  - policyJSON="$(curl -sL https://server.name/jsonquery)" # For a URL, replacing https://server.name/jsonquery with the URL of your file.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Thanks, @astrugatch: I added this line to global variables:
# jsonURL=${10} # URL Hosting JSON for policy_array
#
# And this line replaces the entirety of the policy_array (~ line 503):
# policy_array=("$(curl -sL $jsonURL)")
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Select `policyJSON` based on Configuration selected in "Welcome" dialog (thanks, @drtaru!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function policyJSONConfiguration() {

	outputLineNumberInVerboseDebugMode

	updateScriptLog "WELCOME DIALOG: PolicyJSON Configuration: $symConfiguration"

	# Define the URL to fetch the JSON data
	jsonURL="https://raw.githubusercontent.com/woodleighschool/Setup-Your-Mac/main/Templates/"

	case ${symConfiguration} in

	"Staff")
		# Fetch JSON data for Staff configuration
		policyJSON="$(curl -sL $jsonURL/staff.json)"
		;;

	*) # Catch-all
		# Fetch default JSON data
		policyJSON="$(curl -sL $jsonURL/student.json)"
		;;

	esac

}

####################################################################################################
#
# Failure dialog
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

failureTitle="Failure Detected"
failureMessage="Placeholder message; update in the 'finalise' function"
failureIcon="SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogFailureCMD="$dialogBinary \
--moveable \
--title \"$failureTitle\" \
--message \"$failureMessage\" \
--icon \"$failureIcon\" \
--iconsize 125 \
--width 625 \
--height 45% \
--position topright \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--titlefont 'size=22' \
--messagefont 'size=14' \
--overlayicon \"$overlayicon\" \
--commandfile \"$failureCommandFile\" "

#------------------------ With the execption of the `finalise` function, -------------------------#
#------------------------ edits below these line are optional. -----------------------------------#

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dynamically set `button1text` based on the value of `completionActionOption`
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case ${completionActionOption} in

"Shut Down")
	button1textCompletionActionOption="Shutting Down …"
	progressTextCompletionAction="shut down and "
	;;

"Shut Down "*)
	button1textCompletionActionOption="Shut Down"
	progressTextCompletionAction="shut down and "
	;;

"Restart")
	button1textCompletionActionOption="Restarting …"
	progressTextCompletionAction="restart and "
	;;

"Restart "*)
	button1textCompletionActionOption="Restart"
	progressTextCompletionAction="restart and "
	;;

"Log Out")
	button1textCompletionActionOption="Logging Out …"
	progressTextCompletionAction="log out and "
	;;

"Log Out "*)
	button1textCompletionActionOption="Log Out"
	progressTextCompletionAction="log out and "
	;;

"Sleep"*)
	button1textCompletionActionOption="Close"
	progressTextCompletionAction=""
	;;

"Quit")
	button1textCompletionActionOption="Quit"
	progressTextCompletionAction=""
	;;

*)
	button1textCompletionActionOption="Close"
	progressTextCompletionAction=""
	;;

esac

####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Output Line Number in `verbose` Debug Mode (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function outputLineNumberInVerboseDebugMode() {
	if [[ "${debugMode}" == "verbose" ]]; then updateScriptLog "# # # SETUP YOUR MAC VERBOSE DEBUG MODE: Line No. ${BASH_LINENO[0]} # # #"; fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

	updateScriptLog "Run \"$@\" as \"$loggedInUserID\" … "
	launchctl asuser "$loggedInUserID" sudo -u "$loggedInUser" "$@"

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Calculate Free Disk Space
# Disk Usage with swiftDialog (https://snelson.us/2022/11/disk-usage-with-swiftdialog-0-0-2/)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function calculateFreeDiskSpace() {

	freeSpace=$(diskutil info / | grep -E 'Free Space|Available Space|Container Free Space' | awk -F ":\s*" '{ print $2 }' | awk -F "(" '{ print $1 }' | xargs)
	freeBytes=$(diskutil info / | grep -E 'Free Space|Available Space|Container Free Space' | awk -F "(\\\(| Bytes\\\))" '{ print $2 }')
	diskBytes=$(diskutil info / | grep -E 'Total Space' | awk -F "(\\\(| Bytes\\\))" '{ print $2 }')
	freePercentage=$(echo "scale=2; ( $freeBytes * 100 ) / $diskBytes" | bc)
	diskSpace="$freeSpace free (${freePercentage}% available)"

	updateScriptLog "${1}: Disk Space: ${diskSpace}"

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Welcome" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateWelcome() {
	# updateScriptLog "WELCOME DIALOG: $1"
	echo "$1" >>"$welcomeCommandFile"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Setup Your Mac" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateSetupYourMac() {
	updateScriptLog "SETUP YOUR MAC DIALOG: $1"
	echo "$1" >>"$setupYourMacCommandFile"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update the "Failure" dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogUpdateFailure() {
	updateScriptLog "FAILURE DIALOG: $1"
	echo "$1" >>"$failureCommandFile"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise User Experience
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise() {

	outputLineNumberInVerboseDebugMode

	outputLineNumberInVerboseDebugMode
	calculateFreeDiskSpace "FINALISE USER EXPERIENCE"

	if [[ "${jamfProPolicyTriggerFailure}" == "failed" ]]; then

		outputLineNumberInVerboseDebugMode
		updateScriptLog "Failed polcies detected …"

		if [[ "${failureDialog}" == "true" ]]; then

			outputLineNumberInVerboseDebugMode
			updateScriptLog "Display Failure dialog: ${failureDialog}"

			killProcess "caffeinate"
			if [[ "${brandingBannerDisplayText}" == "true" ]]; then dialogUpdateSetupYourMac "title: Sorry, something went sideways"; fi
			dialogUpdateSetupYourMac "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
			dialogUpdateSetupYourMac "progresstext: Failures detected. Please click Continue for troubleshooting information."
			dialogUpdateSetupYourMac "button1text: Continue …"
			dialogUpdateSetupYourMac "button1: enable"
			dialogUpdateSetupYourMac "progress: reset"

			# Wait for user-acknowledgment due to detected failure
			wait

			dialogUpdateSetupYourMac "quit:"
			eval "${dialogFailureCMD}" &
			sleep 0.3

			updateScriptLog "\n\n# # #\n# FAILURE DIALOG\n# # #\n"
			updateScriptLog "Jamf Pro Policy Name Failures:"
			updateScriptLog "${jamfProPolicyNameFailures}"

			failureMessage="Something went wrong!\n\nFailed policies:\n${jamfProPolicyNameFailures}"

			if [[ -n "${supportTeamName}" ]]; then

				supportContactMessage+="If you need assistance, please contact the **${supportTeamName}**:  \n"

				if [[ -n "${supportTeamPhone}" ]]; then
					supportContactMessage+="- **Telephone:** ${supportTeamPhone}\n"
				fi

				if [[ -n "${supportTeamEmail}" ]]; then
					supportContactMessage+="- **Email:** $supportTeamEmail\n"
				fi

				if [[ -n "${supportTeamWebsite}" ]]; then
					supportContactMessage+="- **Web**: ${supportTeamHyperlink}\n"
				fi

				if [[ -n "${supportKB}" ]]; then
					supportContactMessage+="- **Knowledge Base Article:** $supportTeamErrorKB\n"
				fi

			fi

			failureMessage+="\n\n${supportContactMessage}"

			dialogUpdateFailure "message: ${failureMessage}"

			dialogUpdateFailure "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
			dialogUpdateFailure "button1text: ${button1textCompletionActionOption}"

			# Wait for user-acknowledgment due to detected failure
			wait

			dialogUpdateFailure "quit:"
			quitScript "1"

		else

			outputLineNumberInVerboseDebugMode
			updateScriptLog "Display Failure dialog: ${failureDialog}"

			killProcess "caffeinate"
			if [[ "${brandingBannerDisplayText}" == "true" ]]; then dialogUpdateSetupYourMac "title: Sorry, something went sideways"; fi
			dialogUpdateSetupYourMac "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
			dialogUpdateSetupYourMac "progresstext: Failures detected."
			dialogUpdateSetupYourMac "button1text: ${button1textCompletionActionOption}"
			dialogUpdateSetupYourMac "button1: enable"
			dialogUpdateSetupYourMac "progress: reset"
			dialogUpdateSetupYourMac "progresstext: Errors detected; please try again."

			quitScript "1"

		fi

	else

		outputLineNumberInVerboseDebugMode
		updateScriptLog "All polcies executed successfully"
		if [[ -n "${webhookURL}" ]]; then
			webhookStatus="Successful"
			updateScriptLog "Sending success webhook message"
			webHookMessage
		fi

		if [[ "${brandingBannerDisplayText}" == "true" ]]; then dialogUpdateSetupYourMac "title:Ready, set, done!"; fi
		dialogUpdateSetupYourMac "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
		dialogUpdateSetupYourMac "progresstext: Complete! Please restart to apply the configuration."
		dialogUpdateSetupYourMac "progress: complete"
		dialogUpdateSetupYourMac "button1text: ${button1textCompletionActionOption}"
		dialogUpdateSetupYourMac "button1: enable"

		quitScript "0"

	fi

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value() {
	# set -x
	JSON="$1" osascript -l 'JavaScript' \
		-e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
		-e "JSON.parse(env).$2"
	# set +x
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript for the Welcome dialog (thanks, @bartreardon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value_welcomeDialog() {
	# set -x
	for var in "${@:2}"; do jsonkey="${jsonkey}['${var}']"; done
	JSON="$1" osascript -l 'JavaScript' \
		-e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
		-e "JSON.parse(env)$jsonkey"
	# set +x
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Jamf Pro Policy Custom Events (thanks, @smithjw)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function run_jamf_trigger() {

	outputLineNumberInVerboseDebugMode

	trigger="$1"

	if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then

		updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: TRIGGER: $jamfBinary policy -event $trigger ${suppressRecon}"
		sleep "${debugModeSleepAmount}"

	else

		updateScriptLog "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary policy -event $trigger"
		eval "${jamfBinary} policy -event ${trigger} ${suppressRecon}" # Add comment for policy testing
		# eval "${jamfBinary} policy -event ${trigger} ${suppressRecon} -verbose | tee -a ${scriptLog}"    # Remove comment for policy testing

	fi

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Policy Execution
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function confirmPolicyExecution() {

	outputLineNumberInVerboseDebugMode

	trigger="${1}"
	validation="${2}"
	updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: '${trigger}' '${validation}'"
	if [ "${suppressReconOnPolicy}" == "true" ]; then suppressRecon="-forceNoRecon"; fi

	case ${validation} in

	*/*) # If the validation variable contains a forward slash (i.e., "/"), presume it's a path and check if that path exists on disk

		outputLineNumberInVerboseDebugMode
		if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
			updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: DEBUG MODE: Skipping 'run_jamf_trigger ${trigger}'"
			sleep "${debugModeSleepAmount}"
		elif [[ -f "${validation}" ]]; then
			updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation} exists; skipping 'run_jamf_trigger ${trigger}'"
			previouslyInstalled="true"
		else
			updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation} does NOT exist; executing 'run_jamf_trigger ${trigger}'"
			previouslyInstalled="false"
			run_jamf_trigger "${trigger}"
		fi
		;;

	"None" | "none")

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
		if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
			sleep "${debugModeSleepAmount}"
		else
			run_jamf_trigger "${trigger}"
		fi
		;;

	"Recon" | "recon")

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
		if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
			updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: Set 'debugMode' to false to update computer inventory with the following 'reconOptions': \"${reconOptions}\" …"
			sleep "${debugModeSleepAmount}"
		else
			updateScriptLog "SETUP YOUR MAC DIALOG: Updating computer inventory with the following 'reconOptions': \"${reconOptions}\" …"
			dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Updating …, "
			reconRaw=$(eval "${jamfBinary} recon ${reconOptions} -verbose | tee -a ${scriptLog}")
			computerID=$(echo "${reconRaw}" | grep '<computer_id>' | xmllint --xpath xmllint --xpath '/computer_id/text()' -)
		fi
		;;

	*)

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution Catch-all: ${validation}"
		if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
			sleep "${debugModeSleepAmount}"
		else
			run_jamf_trigger "${trigger}"
		fi
		;;

	esac

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Policy Result
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validatePolicyResult() {

	outputLineNumberInVerboseDebugMode

	trigger="${1}"
	validation="${2}"
	updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Result: '${trigger}' '${validation}'"

	case ${validation} in

	###
	# Absolute Path
	# Simulates pre-v1.6.0 behavior, for example: "/Applications/Microsoft Teams classic.app/Contents/Info.plist"
	###

	*/*)
		updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Result: Testing for \"$validation\" …"
		if [[ "${previouslyInstalled}" == "true" ]]; then
			dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Previously Installed"
		elif [[ -f "${validation}" ]]; then
			dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
		else
			dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
			jamfProPolicyTriggerFailure="failed"
			exitCode="1"
			jamfProPolicyNameFailures+="• $listitem  \n"
		fi
		;;

	###
	# Local
	# Validation within this script, for example: "rosetta" or "filevault"
	###

	"Local")
		case ${trigger} in
		rosetta)
			updateScriptLog "SETUP YOUR MAC DIALOG: Locally Validate Policy Result: Rosetta 2 … " # Thanks, @smithjw!
			dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
			arch=$(arch)
			if [[ "${arch}" == "arm64" ]]; then
				# Mac with Apple silicon; check for Rosetta
				rosettaTest=$(
					arch -x86_64 true 2>/dev/null
					echo $?
				)
				if [[ "${rosettaTest}" -eq 0 ]]; then
					# Installed
					updateScriptLog "SETUP YOUR MAC DIALOG: Locally Validate Policy Result: Rosetta 2 is installed"
					dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Running"
				else
					# Not Installed
					updateScriptLog "SETUP YOUR MAC DIALOG: Locally Validate Policy Result: Rosetta 2 is NOT installed"
					dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
					jamfProPolicyTriggerFailure="failed"
					exitCode="1"
					jamfProPolicyNameFailures+="• $listitem  \n"
				fi
			else
				# Ineligible
				updateScriptLog "SETUP YOUR MAC DIALOG: Locally Validate Policy Result: Rosetta 2 is not applicable"
				dialogUpdateSetupYourMac "listitem: index: $i, status: error, statustext: Ineligible"
			fi
			;;
		*)
			updateScriptLog "SETUP YOUR MAC DIALOG: Locally Validate Policy Result: Local Validation “${validation}” Missing"
			dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Missing Local “${validation}” Validation"
			jamfProPolicyTriggerFailure="failed"
			exitCode="1"
			jamfProPolicyNameFailures+="• $listitem  \n"
			;;
		esac
		;;

	###
	# Remote
	# Validation via a Jamf Pro policy which has a single-script payload, for example: "symvGlobalProtect"
	# See: https://vimeo.com/782561166
	###

	"Remote")
		if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
			updateScriptLog "SETUP YOUR MAC DIALOG: DEBUG MODE: Remotely Confirm Policy Execution: Skipping 'run_jamf_trigger ${trigger}'"
			dialogUpdateSetupYourMac "listitem: index: $i, status: error, statustext: Debug Mode Enabled"
			sleep 0.5
		else
			updateScriptLog "SETUP YOUR MAC DIALOG: Remotely Validate '${trigger}' '${validation}'"
			dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Checking …"
			result=$("${jamfBinary}" policy -event "${trigger}" | grep "Script result:")
			if [[ "${result}" == *"Running"* ]]; then
				dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Running"
			elif [[ "${result}" == *"Installed"* || "${result}" == *"Success"* ]]; then
				dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
			else
				dialogUpdateSetupYourMac "listitem: index: $i, status: fail, statustext: Failed"
				jamfProPolicyTriggerFailure="failed"
				exitCode="1"
				jamfProPolicyNameFailures+="• $listitem  \n"
			fi
		fi
		;;

	###
	# None: For triggers which don't require validation
	# (Always evaluates as: 'success' and 'Installed')
	###

	"None" | "none")

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
		dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Installed"
		;;

	###
	# Recon: For reporting computer inventory update
	# (Always evaluates as: 'success' and 'Updated')
	###

	"Recon" | "recon")

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Confirm Policy Execution: ${validation}"
		dialogUpdateSetupYourMac "listitem: index: $i, status: success, statustext: Updated"
		;;

	###
	# Catch-all
	###

	*)

		outputLineNumberInVerboseDebugMode
		updateScriptLog "SETUP YOUR MAC DIALOG: Validate Policy Results Catch-all: ${validation}"
		dialogUpdateSetupYourMac "listitem: index: $i, status: error, statustext: Error"
		;;

	esac

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Kill a specified process (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function killProcess() {
	process="$1"
	if process_pid=$(pgrep -a "${process}" 2>/dev/null); then
		updateScriptLog "Attempting to terminate the '$process' process …"
		updateScriptLog "(Termination message indicates success.)"
		kill "$process_pid" 2>/dev/null
		if pgrep -a "$process" >/dev/null; then
			updateScriptLog "ERROR: '$process' could not be terminated."
		fi
	else
		updateScriptLog "The '$process' process isn't running."
	fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Completion Action (i.e., Wait, Sleep, Logout, Restart or Shutdown)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function completionAction() {

	outputLineNumberInVerboseDebugMode

	if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then

		# If Debug Mode is enabled, ignore specified `completionActionOption`, display simple dialog box and exit
		runAsUser osascript -e 'display dialog "Setup Your Mac is operating in Debug Mode.\r\r• completionActionOption == '"'${completionActionOption}'"'\r\r" with title "Setup Your Mac: Debug Mode" buttons {"Close"} with icon note'
		exitCode="0"

	else

		shopt -s nocasematch

		case ${completionActionOption} in

		"Shut Down")
			updateScriptLog "COMPLETION ACTION: Shut Down sans user interaction"
			killProcess "Self Service"
			# runAsUser osascript -e 'tell app "System Events" to shut down'
			# sleep 5 && runAsUser osascript -e 'tell app "System Events" to shut down' &
			sleep 5 && shutdown -h now &
			;;

		"Shut Down Attended")
			updateScriptLog "COMPLETION ACTION: Shut Down, requiring user-interaction"
			killProcess "Self Service"
			wait
			# runAsUser osascript -e 'tell app "System Events" to shut down'
			# sleep 5 && runAsUser osascript -e 'tell app "System Events" to shut down' &
			sleep 5 && shutdown -h now &
			;;

		"Shut Down Confirm")
			updateScriptLog "COMPLETION ACTION: Shut down, only after macOS time-out or user confirmation"
			runAsUser osascript -e 'tell app "loginwindow" to «event aevtrsdn»'
			;;

		"Restart")
			updateScriptLog "COMPLETION ACTION: Restart sans user interaction"
			killProcess "Self Service"
			# runAsUser osascript -e 'tell app "System Events" to restart'
			# sleep 5 && runAsUser osascript -e 'tell app "System Events" to restart' &
			sleep 5 && shutdown -r now &
			;;

		"Restart Attended")
			updateScriptLog "COMPLETION ACTION: Restart, requiring user-interaction"
			killProcess "Self Service"
			wait
			# runAsUser osascript -e 'tell app "System Events" to restart'
			# sleep 5 && runAsUser osascript -e 'tell app "System Events" to restart' &
			sleep 5 && shutdown -r now &
			;;

		"Restart Confirm")
			updateScriptLog "COMPLETION ACTION: Restart, only after macOS time-out or user confirmation"
			runAsUser osascript -e 'tell app "loginwindow" to «event aevtrrst»'
			;;

		"Log Out")
			updateScriptLog "COMPLETION ACTION: Log out sans user interaction"
			killProcess "Self Service"
			# sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
			# sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»' &
			sleep 5 && launchctl bootout user/"${loggedInUserID}"
			;;

		"Log Out Attended")
			updateScriptLog "COMPLETION ACTION: Log out sans user interaction"
			killProcess "Self Service"
			wait
			# sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»'
			# sleep 5 && runAsUser osascript -e 'tell app "loginwindow" to «event aevtrlgo»' &
			sleep 5 && launchctl bootout user/"${loggedInUserID}"
			;;

		"Log Out Confirm")
			updateScriptLog "COMPLETION ACTION: Log out, only after macOS time-out or user confirmation"
			sleep 5 && runAsUser osascript -e 'tell app "System Events" to log out'
			;;

		"Sleep"*)
			sleepDuration=$(awk '{print $NF}' <<<"${1}")
			updateScriptLog "COMPLETION ACTION: Sleeping for ${sleepDuration} seconds …"
			sleep "${sleepDuration}"
			killProcess "Dialog"
			updateScriptLog "Goodnight!"
			;;

		"Wait")
			updateScriptLog "COMPLETION ACTION: Waiting for user interaction …"
			wait
			;;

		"Quit")
			updateScriptLog "COMPLETION ACTION: Quitting script"
			exitCode="0"
			;;

		*)
			updateScriptLog "COMPLETION ACTION: Using the default of 'wait'"
			wait
			;;

		esac

		shopt -u nocasematch

	fi

	# Remove custom welcomeBannerImageFileName
	if [[ -e "/var/tmp/${welcomeBannerImageFileName}" ]]; then
		updateScriptLog "COMPLETION ACTION: Removing /var/tmp/${welcomeBannerImageFileName} …"
		rm "/var/tmp/${welcomeBannerImageFileName}"
	fi

	# Remove overlayicon
	if [[ -e ${overlayicon} ]]; then
		updateScriptLog "COMPLETION ACTION: Removing ${overlayicon} …"
		rm "${overlayicon}"
	fi

	exit "${exitCode}"

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome dialog 'infobox' animation (thanks, @bartreadon!)
# To convert emojis, see: https://r12a.github.io/app-conversion/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function welcomeDialogInfoboxAnimation() {
	callingPID=$1
	# clock_emojis=("🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚" "🕛")
	clock_emojis=("&#128336;" "&#128337;" "&#128338;" "&#128339;" "&#128340;" "&#128341;" "&#128342;" "&#128343;" "&#128344;" "&#128345;" "&#128346;" "&#128347;")
	while true; do
		for emoji in "${clock_emojis[@]}"; do
			if kill -0 "$callingPID" 2>/dev/null; then
				dialogUpdateWelcome "infobox: Waiting For Network $emoji"
			else
				break
			fi
			sleep 0.6
		done
	done
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Setup Your Mac dialog 'infobox' animation (thanks, @bartreadon!)
# To convert emojis, see: https://r12a.github.io/app-conversion/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function setupYourMacDialogInfoboxAnimation() {
	callingPID=$1
	# clock_emojis=("🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚" "🕛")
	clock_emojis=("&#128336;" "&#128337;" "&#128338;" "&#128339;" "&#128340;" "&#128341;" "&#128342;" "&#128343;" "&#128344;" "&#128345;" "&#128346;" "&#128347;")
	while true; do
		for emoji in "${clock_emojis[@]}"; do
			if kill -0 "$callingPID" 2>/dev/null; then
				dialogUpdateSetupYourMac "infobox: Waiting For Network $emoji"
			else
				break
			fi
			sleep 0.6
		done
	done
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check Network Quality for Configurations (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function checkNetworkConnectivity() {
	myPID="$$"
	updateScriptLog "WELCOME DIALOG: Display Welcome dialog 'infobox' animation …"
	welcomeDialogInfoboxAnimation "$myPID" &
	welcomeDialogInfoboxAnimationPID="$!"

	while true; do
		if curl -s --connect-timeout 5 https://wdm.jamfcloud.com >/dev/null; then
			updateScriptLog "WELCOME DIALOG: Successfully connected to wdm.jamfcloud.com"
			break
		else
			updateScriptLog "WELCOME DIALOG: Retrying connection to wdm.jamfcloud.com"
			sleep 5
		fi
	done

	kill ${welcomeDialogInfoboxAnimationPID}
	outputLineNumberInVerboseDebugMode

	updateScriptLog "WELCOME DIALOG: Completed wdm.jamfcloud.com connectivity check …"

	# Update the dialog to reflect the connectivity check
	dialogUpdateWelcome "infobox: **Connected**"

	# If option to lock the continue button is set to true, enable the continue button now to let the user progress
	if [[ "${lockContinueBeforeEstimations}" == "true" ]]; then
		updateScriptLog "WELCOME DIALOG: Enabling Continue Button"
		dialogUpdateWelcome "button1: enable"
	fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

	outputLineNumberInVerboseDebugMode

	updateScriptLog "QUIT SCRIPT: Exiting …"

	# Stop `caffeinate` process
	updateScriptLog "QUIT SCRIPT: De-caffeinate …"
	killProcess "caffeinate"

	# Toggle `jamf` binary check-in
	if [[ "${completionActionOption}" == "Log Out"* ]] || [[ "${completionActionOption}" == "Sleep"* ]] || [[ "${completionActionOption}" == "Quit" ]] || [[ "${completionActionOption}" == "wait" ]]; then
		toggleJamfLaunchDaemon
	fi

	# Remove welcomeCommandFile
	if [[ -e ${welcomeCommandFile} ]]; then
		updateScriptLog "QUIT SCRIPT: Removing ${welcomeCommandFile} …"
		rm "${welcomeCommandFile}"
	fi

	# Remove welcomeJSONFile
	if [[ -e ${welcomeJSONFile} ]]; then
		updateScriptLog "QUIT SCRIPT: Removing ${welcomeJSONFile} …"
		rm "${welcomeJSONFile}"
	fi

	# Remove setupYourMacCommandFile
	if [[ -e ${setupYourMacCommandFile} ]]; then
		updateScriptLog "QUIT SCRIPT: Removing ${setupYourMacCommandFile} …"
		rm "${setupYourMacCommandFile}"
	fi

	# Remove failureCommandFile
	if [[ -e ${failureCommandFile} ]]; then
		updateScriptLog "QUIT SCRIPT: Removing ${failureCommandFile} …"
		rm "${failureCommandFile}"
	fi

	# Remove any default dialog file
	if [[ -e /var/tmp/dialog.log ]]; then
		updateScriptLog "QUIT SCRIPT: Removing default dialog file …"
		rm /var/tmp/dialog.log
	fi

	# Check for user clicking "Quit" at Welcome dialog
	if [[ "${welcomeReturnCode}" == "2" ]]; then

		# Remove custom welcomeBannerImageFileName
		if [[ -e "/var/tmp/${welcomeBannerImageFileName}" ]]; then
			updateScriptLog "COMPLETION ACTION: Removing /var/tmp/${welcomeBannerImageFileName} …"
			rm "/var/tmp/${welcomeBannerImageFileName}"
		fi

		# Remove overlayicon
		if [[ -e ${overlayicon} ]]; then
			updateScriptLog "COMPLETION ACTION: Removing ${overlayicon} …"
			rm "${overlayicon}"
		fi

		exitCode="1"
		exit "${exitCode}"

	else

		updateScriptLog "QUIT SCRIPT: Executing Completion Action Option: '${completionActionOption}' …"
		completionAction "${completionActionOption}"

	fi

}

####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Debug Mode Logging Notification
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then
	updateScriptLog "\n\n###\n# ${scriptVersion}\n###\n"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# If Debug Mode is enabled, replace `blurscreen` with `movable`
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]] || [[ "${moveableInProduction}" == "true" ]]; then
	welcomeJSON=${welcomeJSON//blurscreen/moveable}
	dialogSetupYourMacCMD=${dialogSetupYourMacCMD//blurscreen/moveable}
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${welcomeDialog}" == "userInput" ]]; then

	outputLineNumberInVerboseDebugMode

	calculateFreeDiskSpace "WELCOME DIALOG"

	updateScriptLog "WELCOME DIALOG: Starting checkNetworkConnectivity …"
	checkNetworkConnectivity &

	updateScriptLog "WELCOME DIALOG: Write 'welcomeJSON' to $welcomeJSONFile …"
	echo "$welcomeJSON" >"$welcomeJSONFile"

	# If option to lock the continue button is set to true, open welcome dialog with button 1 disabled
	if [[ "${lockContinueBeforeEstimations}" == "true" ]]; then

		updateScriptLog "WELCOME DIALOG: Display 'Welcome' dialog with disabled Continue Button …"
		welcomeResults=$(eval "${dialogBinary} --jsonfile ${welcomeJSONFile} --json --button1disabled")

	else

		updateScriptLog "WELCOME DIALOG: Display 'Welcome' dialog …"
		welcomeResults=$(eval "${dialogBinary} --jsonfile ${welcomeJSONFile} --json")

	fi

	# Evaluate User Input
	if [[ -z "${welcomeResults}" ]]; then
		welcomeReturnCode="2"
	else
		welcomeReturnCode="0"
	fi

	case "${welcomeReturnCode}" in

	0) # Process exit code 0 scenario here
		updateScriptLog "WELCOME DIALOG: ${loggedInUser} entered information and clicked Continue"

		###
		# Extract the various values from the welcomeResults JSON
		###

		userName=$(get_json_value_welcomeDialog "$welcomeResults" "Username")
		assetTag=$(get_json_value_welcomeDialog "$welcomeResults" "Asset Tag")
		position=$(get_json_value_welcomeDialog "$welcomeResults" "Position" "selectedValue" | grep -v "Please select your department")
		campus=$(get_json_value_welcomeDialog "$welcomeResults" "Campus" "selectedValue" | grep -v "Please select your building")

		###
		# Output the various values from the welcomeResults JSON to the log file
		###

		updateScriptLog "WELCOME DIALOG: • User Name: $userName"
		updateScriptLog "WELCOME DIALOG: • Asset Tag: $assetTag"
		updateScriptLog "WELCOME DIALOG: • Position: $position"
		updateScriptLog "WELCOME DIALOG: • Campus: $campus"

		###
		# Select `policyJSON` based on selected Configuration
		###

		case "$position" in
		Class)
			symConfiguration="Students"
			;;
		Student)
			symConfiguration="Students"
			;;
		Staff)
			symConfiguration="Staff"
			;;
		esac

		policyJSONConfiguration

		###
		# Create UserInfo properly list based on supplied paramaters
		###

		cat >/Users/Shared/UserInfo.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Asset Tag</key>
	<string>$assetTag</string>
	<key>Campus</key>
	<string>$campus</string>
	<key>Position</key>
	<string>$position</string>
	<key>Username</key>
	<string>$userName</string>
</dict>
</plist>
EOF

		###
		# Evaluate Various User Input
		###

		# Computer/User Name
		if [[ -n "${userName}" ]]; then
			updateScriptLog "WELCOME DIALOG: Set Computer Name …"
			currentComputerName=$(scutil --get ComputerName)
			currentLocalHostName=$(scutil --get LocalHostName)

			###
			# Try (well not try...) to Generate Computer Name
			# Liam Matthews lil' scwipt
			###

			userNameUpper=$(echo ${userName} | tr '[:lower:]' '[:upper:]')

			# Grabs naming prefix based on campus and position
			case "$campus" in
			Senior\ Campus)
				campusPrefix="S" # Campus prefix for Senior Campus
				;;
			Penbank)
				campusPrefix="P" # Campus prefix for Penbank
				;;
			Minimbah)
				campusPrefix="M" # Campus prefix for Minimbah
				;;
			esac

			case "$position" in
			Student)
				positionPrefix="S" # Position prefix for students
				;;
			Staff)
				positionPrefix="T" # Position prefix for staff
				;;
			Class)
				positionPrefix="C" # Position prefix for classes
				;;
			esac

			computerName="${campusPrefix}${positionPrefix}-${userNameUpper}"

			if [[ "${debugMode}" == "true" ]] || [[ "${debugMode}" == "verbose" ]]; then

				updateScriptLog "WELCOME DIALOG: DEBUG MODE: Would have renamed computer from: \"${currentComputerName}\" to \"${computerName}\" "

			else

				# Set the Computer Name to the user-entered value
				${jamfBinary} setComputerName -name "${computerName}"

				updateScriptLog "WELCOME DIALOG: Renamed computer from: \"${currentComputerName}\" to \"${computerName}\" "

			fi

			# User Name
			reconOptions+="-endUsername \"${userName}\" "
		fi

		# Asset Tag
		if [[ -n "${assetTag}" ]]; then
			reconOptions+="-assetTag \"${assetTag}\" "
		fi

		# Asset Tag
		if [[ "${position}" == "Staff" ]]; then
			reconOptions+="-department \"${position}\" "
		fi

		# Output `recon` options to log
		updateScriptLog "WELCOME DIALOG: reconOptions: ${reconOptions}"

		###
		# Display "Setup Your Mac" dialog (and capture Process ID)
		###

		eval "${dialogSetupYourMacCMD[*]}" &
		sleep 0.3
		until pgrep -q -x "Dialog"; do
			outputLineNumberInVerboseDebugMode
			updateScriptLog "WELCOME DIALOG: Waiting to display 'Setup Your Mac' dialog; pausing"
			sleep 0.5
		done
		updateScriptLog "WELCOME DIALOG: 'Setup Your Mac' dialog displayed; ensure it's the front-most app"
		runAsUser osascript -e 'tell application "Dialog" to activate'
		if [[ -n "${overlayoverride}" ]]; then
			dialogUpdateSetupYourMac "overlayicon: ${overlayoverride}"
		fi
		;;

	2) # Process exit code 2 scenario here
		updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked Quit at Welcome dialog"
		completionActionOption="Quit"
		quitScript "1"
		;;

	3) # Process exit code 3 scenario here
		updateScriptLog "WELCOME DIALOG: ${loggedInUser} clicked infobutton"
		osascript -e "set Volume 3"
		afplay /System/Library/Sounds/Glass.aiff
		;;

	4) # Process exit code 4 scenario here
		updateScriptLog "WELCOME DIALOG: ${loggedInUser} allowed timer to expire"
		quitScript "1"
		;;

	*) # Catch all processing
		updateScriptLog "WELCOME DIALOG: Something else happened; Exit code: ${welcomeReturnCode}"
		quitScript "1"
		;;

	esac

else

	###
	# Select "Catch-all" policyJSON
	###

	outputLineNumberInVerboseDebugMode
	if [[ -n "$presetConfiguration" ]]; then
		symConfiguration="${presetConfiguration}"
	else
		symConfiguration="Catch-all ('Welcome' dialog disabled)"
	fi
	updateScriptLog "WELCOME DIALOG: Using ${symConfiguration} Configuration …"
	policyJSONConfiguration

	###
	# Display "Setup Your Mac" dialog (and capture Process ID)
	###

	eval "${dialogSetupYourMacCMD[*]}" &
	sleep 0.3
	until pgrep -q -x "Dialog"; do
		outputLineNumberInVerboseDebugMode
		updateScriptLog "WELCOME DIALOG: Waiting to display 'Setup Your Mac' dialog; pausing"
		sleep 0.5
	done
	updateScriptLog "WELCOME DIALOG: 'Setup Your Mac' dialog displayed; ensure it's the front-most app"
	runAsUser osascript -e 'tell application "Dialog" to activate'
	if [[ -n "${overlayoverride}" ]]; then
		dialogUpdateSetupYourMac "overlayicon: ${overlayoverride}"
	fi

fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Iterate through policyJSON to construct the list for swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

dialog_step_length=$(get_json_value "${policyJSON}" "steps.length")
for ((i = 0; i < dialog_step_length; i++)); do
	listitem=$(get_json_value "${policyJSON}" "steps[$i].listitem")
	list_item_array+=("$listitem")
	icon=$(get_json_value "${policyJSON}" "steps[$i].icon")
	icon_url_array+=("$icon")
done

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Determine the "progress: increment" value based on the number of steps in policyJSON
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

totalProgressSteps=$(get_json_value "${policyJSON}" "steps.length")
progressIncrementValue=$((100 / totalProgressSteps))
updateScriptLog "SETUP YOUR MAC DIALOG: Total Number of Steps: ${totalProgressSteps}"
updateScriptLog "SETUP YOUR MAC DIALOG: Progress Increment Value: ${progressIncrementValue}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

list_item_string=${list_item_array[*]/%/,}
dialogUpdateSetupYourMac "list: ${list_item_string%?}"
for ((i = 0; i < dialog_step_length; i++)); do
	dialogUpdateSetupYourMac "listitem: index: $i, icon: ${icon_url_array[$i]}, status: pending, statustext: Pending …"
done
dialogUpdateSetupYourMac "list: show"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

updateScriptLog "SETUP YOUR MAC DIALOG: Initial progress bar"
dialogUpdateSetupYourMac "progress: 1"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Close Welcome dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

dialogUpdateWelcome "quit:"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Setup Your Mac's infobox
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

infobox=""

if [[ -n ${comment} ]]; then infobox+="**Comment:**  \n$comment  \n\n"; fi
if [[ -n ${computerName} ]]; then infobox+="**Computer Name:**  \n$computerName  \n\n"; fi
if [[ -n ${userName} ]]; then infobox+="**Username:**  \n$userName  \n\n"; fi
if [[ -n ${assetTag} ]]; then infobox+="**Asset Tag:**  \n$assetTag  \n\n"; fi
if [[ -n ${infoboxConfiguration} ]]; then infobox+="**Configuration:**  \n$infoboxConfiguration  \n\n"; fi
if [[ -n ${campus} ]]; then infobox+="**Campus:**  \n$campus  \n\n"; fi
if [[ -n ${position} ]]; then infobox+="**Position:**  \n$position  \n\n"; fi

updateScriptLog "SETUP YOUR MAC DIALOG: Updating 'infobox'"
dialogUpdateSetupYourMac "infobox: ${infobox}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Setup Your Mac's helpmessage
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

if [[ "${symConfiguration}" != *"Catch-all"* ]]; then

	if [[ -n ${infoboxConfiguration} ]]; then

		if [[ -n "${supportTeamName}" ]]; then

			updateScriptLog "Update 'helpmessage' with support-related information …"

			helpmessage="If you need assistance, please contact:  \n\n**${supportTeamName}**  \n"

			if [[ -n "${supportTeamPhone}" ]]; then
				helpmessage+="- **Telephone:** ${supportTeamPhone}  \n"
			fi

			if [[ -n "${supportTeamEmail}" ]]; then
				helpmessage+="- **Email:** ${supportTeamEmail}  \n"
			fi

			if [[ -n "${supportTeamWebsite}" ]]; then
				helpmessage+="- **Web**: ${supportTeamHyperlink}  \n"
			fi

			if [[ -n "${supportKB}" ]]; then
				helpmessage+="- **Knowledge Base Article:** ${supportTeamErrorKB}  \n"
			fi

		fi

		updateScriptLog "Update 'helpmessage' with Configuration: ${infoboxConfiguration} …"
		helpmessage+="\n**Configuration:**\n- $infoboxConfiguration\n"

		helpmessage+="\n**Computer Information:**  \n"
		helpmessage+="- **Operating System:** ${macOSproductVersion} (${macOSbuildVersion})  \n"
		helpmessage+="- **Serial Number:** ${serialNumber}  \n"
		helpmessage+="- **Dialog:** ${dialogVersion}  \n"
		helpmessage+="- **Started:** ${timestamp}"

	fi

fi

dialogUpdateSetupYourMac "helpmessage: ${helpmessage}"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This for loop will iterate over each distinct step in the policyJSON
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for ((i = 0; i < dialog_step_length; i++)); do

	outputLineNumberInVerboseDebugMode

	# Initialize SECONDS
	SECONDS="0"

	# Creating initial variables
	listitem=$(get_json_value "${policyJSON}" "steps[$i].listitem")
	icon=$(get_json_value "${policyJSON}" "steps[$i].icon")
	progresstext=$(get_json_value "${policyJSON}" "steps[$i].progresstext")
	trigger_list_length=$(get_json_value "${policyJSON}" "steps[$i].trigger_list.length")

	# If there's a value in the variable, update running swiftDialog
	if [[ -n "$listitem" ]]; then
		updateScriptLog "\n\n# # #\n# SETUP YOUR MAC DIALOG: policyJSON > listitem: ${listitem}\n# # #\n"
		dialogUpdateSetupYourMac "listitem: index: $i, status: wait, statustext: Installing …, "
	fi
	if [[ -n "$icon" ]]; then dialogUpdateSetupYourMac "icon: ${icon}"; fi
	if [[ -n "$progresstext" ]]; then dialogUpdateSetupYourMac "progresstext: $progresstext"; fi
	if [[ -n "$trigger_list_length" ]]; then

		for ((j = 0; j < trigger_list_length; j++)); do

			# Setting variables within the trigger_list
			trigger=$(get_json_value "${policyJSON}" "steps[$i].trigger_list[$j].trigger")
			validation=$(get_json_value "${policyJSON}" "steps[$i].trigger_list[$j].validation")
			case ${validation} in
			"Local" | "Remote")
				updateScriptLog "SETUP YOUR MAC DIALOG: Skipping Policy Execution due to '${validation}' validation"
				;;
			*)
				confirmPolicyExecution "${trigger}" "${validation}"
				;;
			esac

		done

	fi

	validatePolicyResult "${trigger}" "${validation}"

	# Increment the progress bar
	dialogUpdateSetupYourMac "progress: increment ${progressIncrementValue}"

	# Record duration
	updateScriptLog "SETUP YOUR MAC DIALOG: Elapsed Time for '${trigger}' '${validation}': $(printf '%dh:%dm:%ds\n' $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60)))"

done

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

outputLineNumberInVerboseDebugMode

finalise
