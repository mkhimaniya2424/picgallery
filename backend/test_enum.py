import enum

class UserRole(str, enum.Enum):
    photographer = "photographer"
    client = "client"

class User:
    def __init__(self, role):
        self.role = role

current_user = User(role="photographer")

if current_user.role != UserRole.photographer:
    print("FAILED! String does not equal Enum!")
else:
    print("PASSED! String equals Enum!")

current_user2 = User(role=UserRole.photographer)

if current_user2.role != UserRole.photographer:
    print("FAILED! Enum does not equal Enum!")
else:
    print("PASSED! Enum equals Enum!")
