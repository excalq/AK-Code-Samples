import ("strings")

// Golang version of "defanging" and IP address
// Replaces "." with "[.]"
// "255.100.50.0" becomes "255[.]100[.]50[.]0"
//
func defangIPaddr(address string) string {
    return strings.Replace(address, ".", "[.]", -1)
}