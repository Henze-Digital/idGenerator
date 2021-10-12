xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace hwh="https://henze-digital.de/ns/idGen";

let $collection := '/db/apps/idGenerator/'
let $resourceCollPath := concat($collection, 'data/temp/')
let $resource := 'usersIdGen.xml'
let $resourceData := doc(concat($resourceCollPath, $resource)) 

let $creatingUsers := for $user in $resourceData//hwh:user
                        let $userName := $user/string(@name)
                        let $userPswd := $user/string(@password)
                        return
                            sm:create-account($userName, $userPswd, 'hwh')
                            
return
    xmldb:remove($resourceCollPath, $resource)