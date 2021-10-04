xquery version "3.1";

module namespace app="http://www.raff-archiv.ch/idGenerator/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.raff-archiv.ch/idGenerator/config" at "/db/apps/idGenerator/modules/config.xqm";
import module namespace functx="http://www.functx.com";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace hwh="http://henze-digital.de/ns/hwh";

(:~
 : This is a sample templating function. It will be called by the templating module if
 : it encounters an HTML element with an attribute: data-template="app:test" or class="app:test" (deprecated).
 : The function has to take 2 default parameters. Additional parameters are automatically mapped to
 : any matching request or function parameter.
 :
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
 
declare function hwh:compute-check-digit($id as xs:string) as xs:string {
    let $weights := (2, 4, 6, 8, 9, 5, 3)
    let $weighted-codepoints := for $i at $c in string-to-codepoints($id) return $i * $weights[$c]
    return
        hwh:int2hex(sum($weighted-codepoints) mod 16)
};

declare function hwh:int2hex($number as xs:int) as xs:string {
    let $chars := ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F')
    let $div := $number div 16
    let $count := floor($div)
    let $remainder := ($div - $count) * 16
    return
        concat(
            if($count gt 15) 
            then hwh:int2hex(xs:integer($count))
            else if($number gt 15) then $chars[$count +1]
            else (),
            $chars[$remainder +1]
        )
};


declare function app:switchType($prefix as xs:string) as xs:string {
    switch ($prefix)
        case 'A01' return 'Brief'
        case 'A02' return 'Werk'
        case 'A03' return 'Personen'
        case 'A04' return 'Institutionen'
        case 'A05' return 'Bibliographikum'
        default return 'notDefinied'
};

declare function app:typeList($node as node(), $model as map(*)) {
    let $dataCollection := collection ('/db/apps/idGenerator/data/')
    let $prefixes := $dataCollection//hwh:generated/@prefix/string()

    for $prefix in $prefixes
    let $label := app:switchType($prefix)

    order by $prefix
    return
        <li class="list-group-item">
                    <a href="generateID.html?prefix={$prefix}">
                        <button type="button" class="btn btn-secondary">{$label}</button>
                    </a> <span>&#160;</span> zuletzt verwendet:
                    {app:getLatest($prefix, 'id')} <span>&#160;</span>
                    {app:getLatest($prefix, 'date')}
                    </li>
};

declare function app:generateID($prefix as xs:string) as node() {
    let $idList := doc(concat('/db/apps/idGenerator/data/generatedIdList-', $prefix, '.xml'))//hwh:generated
    let $latestIdNo := $idList//hwh:id[last()]/@n/number()
    let $log := console:log($latestIdNo)
(:    let $latestValue := substring-after($latestIdNo, $prefix):)
    let $newValue := concat($prefix, 
            functx:reverse-string(
                    functx:pad-string-to-length(
                        functx:reverse-string(
                            hwh:int2hex($latestIdNo + 1)
                        )
                        , '0', 4
                    )
                )
            )
    let $checkDigit := hwh:compute-check-digit($newValue)
    let $newID := concat($newValue, $checkDigit)
    let $user := xs:string(sm:id()//sm:real//sm:username)
    let $date := substring(string(current-date()), 1,10)
    let $time := substring(string(current-time()),1,8)
    let $input := <id xmlns="http://henze-digital.de/ns/hwh"
                      n="{$latestIdNo + 1}"
                      value="{$newID}"
                      who="{$user}"
                      when="{$date}"
                      at="{$time}"
                      dateTime="{current-dateTime()}"/>
    let $prefixSwitched := app:switchType($prefix)
    return
        (
            <div>
                <h5>Ihre <b>{$prefixSwitched}</b>-ID:</h5>
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
    let $prefix := request:get-parameter ('prefix', 'NotDefined')
    return
        app:generateID($prefix)
};


declare function app:getLatest($prefix as xs:string, $object as xs:string) {
    let $idList := doc(concat('/db/apps/idGenerator/data/generatedIdList-', $prefix, '.xml'))//hwh:generated
    let $latestEntry := $idList//hwh:id[last()]
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
