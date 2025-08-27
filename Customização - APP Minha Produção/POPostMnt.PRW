#INCLUDE "TOTVS.CH"
 
User Function POPostMnt()
    Local cJson     := PARAMIXB[1]
    Local oJson     := JsonObject():New()
 
    //Converte a string JSON para objeto JSON, para que seja possível manipular os dados.
    oJson:FromJson(cJson)
 
    If ALLTRIM(oJson["FORMCODE"]) == "000006"
    
        FWLogMsg("INFO", "LAST"/*cTransactionId*/, "cJson antes de alterar ", /*cCategory*/, /*cStep*/, /*cMsgId*/,cJson, /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
        oJson["C2_NUM"]     := oJson["C2_OPAUX"]
        oJson["C2_ITEM"]    := oJson["C2_ITEMAUX"]
        oJson["C2_DESCPRO"] := oJson["C2_PRODESC"]
       
    EndIf
 
    //Converte o objeto Json com as informações manipuladas em uma String Json.
    cJson := oJson:ToJson()
 
    FWLogMsg("INFO", "LAST"/*cTransactionId*/, "cJson depois de alterar ", /*cCategory*/, /*cStep*/, /*cMsgId*/,cJson, /*nMensure*/, /*nElapseTime*/, /*aMessage*/)
    
    //Limpa da memória o objeto Json utilizado.
    FREEOBJ( oJson )
 
Return cJson
