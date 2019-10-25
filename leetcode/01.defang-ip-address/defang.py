class Solution:
    def defangIPaddr(self, address: str) -> str:
        """Python3 version of defanging an IP address
        """
        return address.replace(".", "[.]")
