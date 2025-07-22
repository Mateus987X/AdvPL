//Este código é um ponto de entrada (PE) no sistema Protheus 
//da TOTVS que customiza o comportamento do cadastro de 
//clientes (tabela SA1), especificamente para operações na filial "05". //


#include "FWMVCDEF.CH"
#include "Protheus.ch"
#Include "TopConn.ch"


//-------------------------------------------------------------------

/*/{Protheus.doc} MyCRMA980

Ponto de Entrada do Cadastro de Clientes (MVC)
@param      Nao ha
@return     Varios. Dependerá de qual PE esta sendo executado.
@author     Faturamento
@version    12.1.17 / Superior
@since      Mai/2021
/*/

//-------------------------------------------------------------------

User Function CRMA980() ///cXXX1,cXXX2,cXXX3,cXXX4,cXXX5,cXXX6
    Local aParam    := PARAMIXB
    Local xRet      := .T.
    Local lIsGrid   := .F.
    Local i
    Local aCampos
    Local cCampo
    Local cIDPonto  := ''
    Local cIDModel  := ''
    Local oObj      := NIL

    If aParam <> NIL
        oObj        := aParam[1]
        cIDPonto    := aParam[2]
        cIDModel    := aParam[3]
        lIsGrid     := (Len(aParam) > 3)
        nOperation  := oObj:GetOperation()

        If cIDPonto == "MODELCOMMITNTTS"

            If SELECT("TRB") > 0
                dbSelectArea("TRB")
                dbCloseArea()  
            EndIf

            //Pegand os campos/tipos da SA1
            cQuery := " SELECT X3_CAMPO, X3_TIPO "
            cQuery += " FROM " + "SX3010" + " SX3 " 
            cQuery += " WHERE X3_ARQUIVO = 'SA1' AND D_E_L_E_T_ = '' AND X3_CAMPO NOT IN ('R_E_C_N_O_', 'D_E_L_E_T_', 'I_N_S_D_T_', 'S_T_A_M_P_')"

            cQuery := ChangeQuery(cQuery)
            dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) 

            //Pega os campos da SA1 
            aCampos := {}
            TRB->(dbGoTop())
            While !TRB->(EOF())
                AAdd(aCampos, {TRB->X3_CAMPO, TRB->X3_TIPO})
                TRB->(dbSkip())
            EndDo
            TRB->(dbCloseArea())

            If nOperation == 3
                    
                RecLock("SA1", .T.)
                
                //Itera  o
                For i := 1 To Len(aCampos)
                    cCampo := aCampos[i][1]
                    cTipo  := aCampos[i][2]
                    
                    If cCampo != "A1_FILIAL"
                        nPos := FieldPos(cCampo)
                        If nPos > 0
                            // Pega o valor do campo na mem ria (M->) ou da SA1 original
                            If Type("M->"+cCampo) != "U"
                                FieldPut(nPos, &("M->"+cCampo))
                            ElseIf Type("SA1->"+cCampo) != "U"
                                FieldPut(nPos, SA1->&(cCampo))
                            EndIf
                        EndIf
                    EndIf
                Next

                // For a a filial 05
                FieldPut(FieldPos("A1_FILIAL"), "05    ")

                MsUnlock() 

                
            EndIf

            // Alteracao
            If nOperation == 4
                	
                DbSelectArea("SA1")
                DbSetOrder(1) // A1_FILIAL+A1_COD+A1_LOJA

                If DbSeek("05    " + SA1->A1_COD + SA1->A1_LOJA)
                    // Bloqueia o registro para alteração
                    RecLock("SA1", .F.)
                    
                    // Atualiza todos os campos 
                    For i := 1 To Len(aCampos)
                        cCampo := aCampos[i][1]
                        cTipo := aCampos[i][2]
                        nPos := FieldPos(cCampo)
                        If nPos > 0
                            // Pega o valor do campo na memória (M->) ou da SA1 original (matriz)
                            If alltrim(cCampo) <> "A1_FILIAL"
                                If Type("M->"+cCampo) != "U"
                                    FieldPut(nPos, &("M->"+cCampo))
                                ElseIf Type("SA1->"+cCampo) != "U"
                                    // Usa o valor da matriz (SA1 original)
                                    FieldPut(nPos, SA1->&(cCampo))
                                EndIf
                            EndIf
                        EndIf
                    Next
                    MsUnlock()
                EndIf
            EndIf

            // Exclusao
            If nOperation == 5
                If ApMsgNoYes("Você tem CERTEZA que deseja excluir este registro?", "Confirmar")
                    cQuery := " UPDATE " + RetSqlName("SA1") 
                    cQuery += " SET D_E_L_E_T_ ='*' "
                    cQuery += " WHERE A1_COD = '"+SA1->A1_COD+"' "
                    cQuery += " AND A1_LOJA  = '"+SA1->A1_LOJA+"' "
                    cQuery += " AND A1_FILIAL = '05    '"
                    TcSqlExec(cQuery)
                EndIf
            EndIf
        EndIf
    EndIf
Return xRet
