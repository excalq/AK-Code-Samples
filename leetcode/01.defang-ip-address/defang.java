/**
/* Java tool for "defanging" an IP address.
/* Replaces "." with "[.]"
/* "255.100.50.0" becomes "255[.]100[.]50[.]0"
*/
class Solution {
    public String defangIPaddr(String address) {
        StringBuffer defanged = new StringBuffer();
        for (int i = 0; i < address.length(); i++) {
            char c = address.charAt(i);

            if (c == '.') {
                defanged.append('[');
                defanged.append(c);
                defanged.append(']');
            } else {
                defanged.append(c);
            }
        }
        return defanged.toString();
    }
}