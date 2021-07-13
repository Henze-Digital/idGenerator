xquery version "3.1";

module namespace app="http://www.raff-archiv.ch/idGenerator/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.raff-archiv.ch/idGenerator/config" at "config.xqm";
declare namespace sm = "http://exist-db.org/xquery/securitymanager";

(:~
 : This is a sample templating function. It will be called by the templating module if
 : it encounters an HTML element with an attribute: data-template="app:test" or class="app:test" (deprecated). 
 : The function has to take 2 default parameters. Additional parameters are automatically mapped to
 : any matching request or function parameter.
 : 
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)

declare function app:switchType($type as xs:string) as xs:string {
    switch ($type)
        case 'A' return 'Brief'
        case 'B' return 'Werk'
        case 'C' return 'Personen'
        case 'D' return 'Institutionen'
        case 'E' return 'Schriften'
        case 'F' return 'Ereignis'
        case 'G' return 'Bibliographikum'
        default return 'notDefinied'
};

declare function app:typeList($node as node(), $model as map(*)) {
    let $dataCollection := collection ('/db/apps/idGenerator/data/')
    let $types := $dataCollection//generated/@prefix/string()
    
    for $type in $types
    let $label := app:switchType($type)
    
    order by $type
    return
        <li class="list-group-item">
                    <a href="generateID.html?type={$type}">
                        <button type="button" class="btn btn-secondary">{$label}</button>
                    </a> <span>&#160;</span> zuletzt verwendet:
                    {app:getLatest($type, 'id')} <span>&#160;</span>
                    {app:getLatest($type, 'date')}
                    </li>
};

declare function app:generateID($type as xs:string) as node() {
    let $idList := doc(concat('/db/apps/idGenerator/data/generatedIdList-', $type, '.xml'))//generated
    let $latestID := $idList//id[last()]/@value
    let $latestValue := substring-after($latestID, $type)
    let $newValue := number($latestValue) + 1
    let $newID := concat($type, format-number($newValue, '00000'))
    let $user := xs:string(sm:id()//sm:real//sm:username)
    let $date := substring(string(current-date()), 1,10)
    let $time := substring(string(current-time()),1,8)
    let $input := <id value="{$newID}" who="{$user}" when="{$date}" at="{$time}" dateTime="{current-dateTime()}"/>
    let $typeSwitched := app:switchType($type)
    return
        (
            <div>
                <h5>Ihre <b>{$typeSwitched}</b>-ID:</h5>
                <h1>{$newID}</h1>
                <p>Erstellt: {$date} um {$time}</p>
                <div>
                    <a href="index.html"><button type="button" class="btn btn-success">Fertig</button></a>
                </div>
                <script type="text/javascript">
                    location.reload();
                    return false;
                </script>
            </div>,
            update insert $input into $idList
        )
};


declare function app:generateID($node as node(), $model as map(*)) {
    let $type := request:get-parameter ('type', 'NotDefined')
    return
        app:generateID($type)
};


declare function app:getLatest($type as xs:string, $object as xs:string) {
    let $idList := doc(concat('/db/apps/idGenerator/data/generatedIdList-', $type, '.xml'))//generated
    let $latestEntry := $idList//id[last()]
    let $latestID := string($latestEntry/@value)
    let $latestDate := string($latestEntry/@when)
    let $latestDateAt := string($latestEntry/@at)
    
    return
        if($object = 'id')
        then(<span>{$latestID}</span>)
        else if ($object = 'date')
        then(<span>({$latestDate} um {$latestDateAt})</span>)
        else()
        
};