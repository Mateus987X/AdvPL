/*/{Protheus.doc} MATA010 MVC

Função de tratamento do cadastro de produtos (SB1) para replicação de dados na filial 05.
- Realiza operações de inclusão, alteração e exclusão de produtos na filial 05 (TR01) com base nas ações na matriz
- Sincroniza os dados complementares na tabela SB5 entre as filiais
- Utiliza transação SQL para garantir a integridade dos dados
- Trabalha em conjunto com o modelo MVC de produtos (ITEM)/*//





#include "FWMVCDEF.CH"
#include "Protheus.ch"
#Include "TopConn.ch"
#include "parmtype.ch"


//-------------------------------------------------------------------

/*/{Protheus.doc} MATA010 MVC

Ponto de Entrada do Cadastro de PRODUTOSs (MVC)
@param      Nao ha
@return     Varios. Dependerá de qual PE esta sendo executado.
@author     Faturamento
@version    12.1.17 / Superior
@since      Mai/2021
/*/

//-------------------------------------------------------------------

User Function ITEM() ///cXXX1,cXXX2,cXXX3,cXXX4,cXXX5,cXXX6
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

        If cIDModel == 'ITEM'
        
            If cIDPonto == "MODELCOMMITNTTS"

                // Exclusao
                If nOperation == 5
                    If ApMsgNoYes("Você tem CERTEZA que deseja excluir este registro?", "Confirmar")
                        cQuery := " UPDATE " + RetSqlName("SB1") 
                        cQuery += " SET D_E_L_E_T_ ='*' "
                        cQuery += " WHERE B1_COD = '"+SB1->B1_COD+"' "
                        cQuery += " AND B1_FILIAL = '05    '"
                        TcSqlExec(cQuery)
                    EndIf
                EndIf

                If SELECT("TRB") > 0
                    dbSelectArea("TRB")
                    dbCloseArea()  
                EndIf

                //Pegand os campos/tipos da SB1
                cQuery := " SELECT X3_CAMPO, X3_TIPO "
                cQuery += " FROM " + "SX3010" + " SX3 " 
                cQuery += " WHERE X3_ARQUIVO = 'SB1' AND D_E_L_E_T_ = '' AND X3_CAMPO NOT IN ('R_E_C_N_O_', 'D_E_L_E_T_', 'I_N_S_D_T_', 'S_T_A_M_P_')"

                cQuery := ChangeQuery(cQuery)
                dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) 

                //Pega os campos da SB1 
                aCampos := {}
                TRB->(dbGoTop())
                While !TRB->(EOF())
                    AAdd(aCampos, {TRB->X3_CAMPO, TRB->X3_TIPO})
                    TRB->(dbSkip())
                EndDo
                TRB->(dbCloseArea())

                If nOperation == 3
                        
                    RecLock("SB1", .T.)
                    
                    //Itera  o
                    For i := 1 To Len(aCampos)
                        cCampo := aCampos[i][1]
                        cTipo  := aCampos[i][2]
                        
                        If cCampo != "B1_FILIAL"
                            nPos := FieldPos(cCampo)
                            If nPos > 0
                                // Pega o valor do campo na mem ria (M->) ou da SB1 original
                                If Type("M->"+cCampo) != "U"
                                    FieldPut(nPos, &("M->"+cCampo))
                                ElseIf Type("SB1->"+cCampo) != "U"
                                    FieldPut(nPos, SB1->&(cCampo))
                                EndIf
                            EndIf
                        EndIf
                    Next

                    // For a a filial 05
                    FieldPut(FieldPos("B1_FILIAL"), "05    ")
                    MsUnlock() 

                    dBselectarea("SB5")
                    DbSetOrder(1)
                    dbGoTop()
                    
                    SB5->(dbSeek("01IN01"+M->B1_COD))

                    //QURY SB5
                    //Pegand os campos/tipos da SB1
                    cQuery := " SELECT X3_CAMPO, X3_TIPO "
                    cQuery += " FROM " + "SX3010" + " SX3 " 
                    cQuery += " WHERE X3_ARQUIVO = 'SB5' AND D_E_L_E_T_ = '' AND X3_CAMPO NOT IN ('R_E_C_N_O_', 'D_E_L_E_T_', 'I_N_S_D_T_', 'S_T_A_M_P_')"

                    cQuery := ChangeQuery(cQuery)
                    dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) 

                    //Pega os campos da SB5
                    aCampos := {}
                    TRB->(dbGoTop())
                    While !TRB->(EOF())
                        AAdd(aCampos, {TRB->X3_CAMPO, TRB->X3_TIPO})
                        TRB->(dbSkip())
                    EndDo
                    TRB->(dbCloseArea())

                    // Bloqueia o registro para inclusao
                    aCamposValue := {}

                   For i:=1 to len(aCampos)
                        cCampo := aCampos[i][1]
                        AAdd(aCamposValue, {cCampo,SB5->(FieldGet(FieldPos(cCampo)))})
                    Next

                    RecLock("SB5", .T.)
                                        
                    // Atualiza todos os campos 
                    For i := 1 To Len(aCampos)
                        cCampo := aCampos[i][1]
                        cTipo  := aCampos[i][2]
                        nPos   := FieldPos(cCampo)
                        If nPos > 0
                            // Pega o valor do campo na memória (M->) ou da SB1 original (matriz)
                            If alltrim(cCampo) <> "B5_FILIAL"
                               FieldPut(nPos, aCamposValue[i][2])
                            EndIf
                        EndIf
                    Next
                    FieldPut(FieldPos("B5_FILIAL"), "05TR01")
                    MsUnlock() 
                  
                EndIf

                // Alteracao
                If nOperation == 4
                        
                    DbSelectArea("SB1")
                    DbSetOrder(1) // A1_FILIAL+A1_COD+A1_LOJA

                    If DbSeek("05    " + SB1->B1_COD)
                        // Bloqueia o registro para alteração
                        RecLock("SB1", .F.)
                        
                        // Atualiza todos os campos 
                        For i := 1 To Len(aCampos)
                            cCampo := aCampos[i][1]
                            cTipo := aCampos[i][2]
                            nPos := FieldPos(cCampo)
                            If nPos > 0
                                // Pega o valor do campo na memória (M->) ou da SB1 original (matriz)
                                If alltrim(cCampo) <> "B1_FILIAL"
                                    If Type("M->"+cCampo) != "U"
                                        FieldPut(nPos, &("M->"+cCampo))
                                    ElseIf Type("SB1->"+cCampo) != "U"
                                        // Usa o valor da matriz (SB1 original)
                                        FieldPut(nPos, SB1->&(cCampo))
                                    EndIf
                                EndIf
                            EndIf
                        Next
                        MsUnlock()

                        //Altera informacoes complementar na 05
                        dBselectarea("SB5")
                        DbSetOrder(1)
                        dbGoTop()
                        
                        SB5->(dbSeek("01IN01"+M->B1_COD))

                        //QURY SB5
                        //Pegand os campos/tipos da SB1
                        cQuery := " SELECT X3_CAMPO, X3_TIPO "
                        cQuery += " FROM " + "SX3010" + " SX3 " 
                        cQuery += " WHERE X3_ARQUIVO = 'SB5' AND D_E_L_E_T_ = '' AND X3_CAMPO NOT IN ('R_E_C_N_O_', 'D_E_L_E_T_', 'I_N_S_D_T_', 'S_T_A_M_P_')"

                        cQuery := ChangeQuery(cQuery)
                        dbUseArea(.T.,"TOPCONN",TcGenQry(,,cQuery),"TRB",.T.,.T.) 

                        //Pega os campos da SB5
                        aCampos := {}
                        TRB->(dbGoTop())
                        While !TRB->(EOF())
                            AAdd(aCampos, {TRB->X3_CAMPO, TRB->X3_TIPO})
                            TRB->(dbSkip())
                        EndDo
                        TRB->(dbCloseArea())

                        // Bloqueia o registro para inclusao
                        aCamposValue := {}

                        For i:=1 to len(aCampos)
                            cCampo := aCampos[i][1]
                            AAdd(aCamposValue, {cCampo,SB5->(FieldGet(FieldPos(cCampo)))})
                        Next

                        RecLock("SB5", .F.)
                        // Atualiza todos os campos 
                        For i := 1 To Len(aCampos)
                            cCampo := aCampos[i][1]
                            cTipo  := aCampos[i][2]
                            nPos   := FieldPos(cCampo)
                            If nPos > 0
                                // Pega o valor do campo na memória (M->) ou da SB1 original (matriz)
                                If alltrim(cCampo) <> "B5_FILIAL"
                                   FieldPut(nPos, aCamposValue[i][2])
                                EndIf
                            EndIf
                        Next
                        MsUnlock() 

                        SB5->(dbSeek("05TR01"+M->B1_COD))
                        RecLock("SB5", .F.)
                                            
                        // Atualiza todos os campos 
                        For i := 1 To Len(aCampos)
                            cCampo := aCampos[i][1]
                            cTipo  := aCampos[i][2]
                            nPos   := FieldPos(cCampo)
                            If nPos > 0
                                // Pega o valor do campo na memória (M->) ou da SB1 original (matriz)
                                If alltrim(cCampo) <> "B5_FILIAL"
                                   FieldPut(nPos, aCamposValue[i][2])
                                EndIf
                            EndIf
                        Next
                        MsUnlock() 

                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
Return xRet
