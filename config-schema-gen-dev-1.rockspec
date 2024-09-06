rockspec_format = "3.0"
package = "config-schema-gen"
version = "dev-1"
source = {
   url = "https://gitlab.com/ochaton/config-schema-gen.git"
}
description = {
   summary = "Tarantool 3.x Config schema generator",
   detailed = "Tarantool 3.x Config schema generatir",
   homepage = "https://github.com/tarantool/tarantool",
   license = "MIT"
}
dependencies = {
   "tarantool ~> 3",
   "argparse",
}
build = {
   type = "builtin",
   modules = {},
   install = {
      bin = {
         ["config-schema-gen"] = "schema-gen.lua"
      }
   },
}
