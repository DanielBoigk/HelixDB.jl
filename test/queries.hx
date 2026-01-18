QUERY AddUser(name: String, age: U8) =>
    user <- AddN<User>({
        name: name,
        age: age
    })
    RETURN user
