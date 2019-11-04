class Solution:
    def containsDuplicate(self, nums: List[int]) -> bool:
        ht: Dict[bool]= {}
        for n in nums:
            if n in ht:
                return True # dupe found
            ht[n] = True
        return False
