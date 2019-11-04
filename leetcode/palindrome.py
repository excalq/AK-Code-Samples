from collections import deque
import string

class Solution:
    def isPalindrome(self, s: str) -> bool:
    """Returns whether the string is a palindrome.
       This copies just letters into a deque, and symetrically pops both ends.
    """
        d = deque()
        for c in s:
            if c in string.ascii_letters or c in string.digits:
                d.append(c.lower())
        while len(d) > 1:
            if d.pop() != d.popleft():
                return False
        return True
