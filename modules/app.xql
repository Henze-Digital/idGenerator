xquery version "3.1";

module namespace app="http://www.raff-archiv.ch/idGenerator/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.raff-archiv.ch/idGenerator/config" at "/db/apps/idGenerator/modules/config.xqm";
import module namespace functx="http://www.functx.com";
import module namespace console="http://exist-db.org/xquery/console";

declare namespace sm = "http://exist-db.org/xquery/securitymanager";
declare namespace hwh="http://henze-digital.de/ns/hwh";

(:~
 : This function generates a check digit for an given id.
 : @param $id the id has to be inserted as string
 :)
declare function hwh:compute-check-digit($id as xs:string) as xs:string {
    let $weights := (2, 4, 6, 8, 9, 5, 3)
    let $weighted-codepoints := for $i at $c in string-to-codepoints($id) return $i * $weights[$c]
    return
        hwh:int2hex(sum($weighted-codepoints) mod 16)
};

(:~
 : This function converts an integer into a hexadecimal string
 : @param $number the insert has to be a xs:init
 :)
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

(:~
 : This function switches the prefix of an id into a term.
 : @param $prefix is required as string
 :)
declare function app:switchPrefix($prefix as xs:string) as xs:string {
    switch ($prefix)
        case 'A00' return 'Personen'
        case 'A02' return 'Werke'
        case 'A03' return 'Schriften'
        case 'A04' return 'Briefe'
        case 'A05' return 'News'
        case 'A06' return 'Tagebuch-Tag'
        case 'A08' return 'Organisation'
        case 'A10' return 'Dokument'
        case 'A11' return 'Bibliographikum'
        case 'A12' return 'Addenda'
        case 'A13' return 'Orte'
        default return 'prefixNotDefinied'
};

(:~
 : This function generates the main list for the index page
 : that lists all prefixes available.
 :)
declare function app:prefixList($node as node(), $model as map(*)) {
    let $dataCollection := collection ('/db/apps/idGenerator/data/')
    let $prefixes := $dataCollection//hwh:generated/@prefix
    
    for $prefix in $prefixes
    let $label := app:switchPrefix($prefix)
    let $disabled := if($prefix/self::node()/hwh:id[@n="0"]) then('disabled') else()
    order by $prefix
    return
        <li class="list-group-item">
            <a href="generateID.html?prefix={$prefix}" class="{$disabled}">
                <button type="button" class="btn btn-secondary {$disabled}" id="refreshPage">{$label}</button>
            </a> <span>&#160;</span> zuletzt verwendet:
            {app:getLatest($prefix, 'id')} <span>&#160;</span>
            {app:getLatest($prefix, 'date')}
        </li>
};

(:~
 : In this function a new id will be generated. It is called by the prefix.
 : The function will find the ids already in use and will generate a new one.
 : @param $prefix has to be inserted as string
 :)

declare function app:generateID($node as node(), $model as map(*)) {
    let $prefix := request:get-parameter ('prefix', 'NotDefined')
    let $idList := doc(concat('/db/apps/idGenerator/data/idsInUse-', $prefix, '.xml'))//hwh:generated
    let $latestIdNo := $idList//hwh:id[last()]/@n/number()
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
    let $log := console:log(concat('new ID:',$newID))
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
    let $prefixSwitched := app:switchPrefix($prefix)
    return
        (
            <div>
                <h5>Die ID für den Typ <b>{$prefixSwitched}</b> lautet:</h5>
                <h1><span id="newIdValue">{$newID}</span></h1>
                <p>Erstellt: {$date} um {$time}</p>
                <div>
                    <a href="index.html"><button type="button" class="btn btn-success">Fertig</button></a>
                </div>
                <!--<script>
                    window.onload = function() {{
                          if(!window.location.hash) {{
                              window.location = window.location + '#loaded';
                              window.location.reload();
                          }}
                      }}
                </script>-->
            </div>,
            update insert $input into $idList
        )
};


declare function app:getLatest($prefix as xs:string, $object as xs:string) {
    let $idList := doc(concat('/db/apps/idGenerator/data/idsInUse-', $prefix, '.xml'))//hwh:generated
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

declare function app:logInAlert($node as node(), $model as map(*)) {
    let $username := xs:string(sm:id()//sm:real//sm:username)
    return
        <div>Hallo <b>{$username}</b>.<br/>Du bist erfolgreich angemeldet! Bitte wähle eine Kategorie!</div>
};
