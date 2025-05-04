// 4. Màquina d'Estats
IF #HabilitarControl THEN
    CASE #Estat OF
        0: // Repòs
            #EnMoviment := FALSE;
            #VelocitatActual := 0.0;
            #RampaActiva := FALSE;
            #ComptePasos := 0;
            IF #sPosicioActual_Passos <> #PosicioDesitjadaPassos THEN
                #Estat := 10; // Passar a Preparar Moviment
            END_IF;
            
        10: // Preparar Moviment
            #EnMoviment := TRUE;
            #DireccioAssignada := (#PosicioDesitjadaPassos > #sPosicioActual_Passos) XOR NOT #DireccioPerObrir;
            #VelocitatActual := 10.0; // Velocitat inicial
            #RampaActiva := TRUE;
            #ComptePasos := 0;
            #Estat := 20; // Passar a Moviment
            #sTimerPols(IN := TRUE,
                        PT := #PT);
            #PasActual := FALSE;
            
        20: // Moviment
            #sTimerPols(IN := TRUE,
                        PT := #TempsPolsActual);
            
            IF #sTimerPols.Q THEN
                // Reiniciar el temporitzador per al següent pols
                
                // Generar pols i actualitzar direcció
                #PasActual := NOT #PasActual;
                #MotorPols := #PasActual;
                #MotorDireccio := #DireccioAssignada;
                
                // Actualitzar posició segons la direcció
                IF #DireccioAssignada = #DireccioPerObrir THEN
                    #sPosicioActual_Passos := #sPosicioActual_Passos + 1;
                ELSE
                    #sPosicioActual_Passos := #sPosicioActual_Passos - 1;
                END_IF;
                
                // Control de Rampa
                IF #RampaActiva THEN
                    #ComptePasos := #ComptePasos + 1;
                    IF #ComptePasos >= #PasosPerRampa THEN
                        #ComptePasos := 0;
                        IF #sPosicioActual_Passos < (#PosicioDesitjadaPassos + #CarreraTotal_Passos / 10) AND
                            #sPosicioActual_Passos > (#PosicioDesitjadaPassos - #CarreraTotal_Passos / 10) THEN
                            // Desaccelerar
                            #VelocitatActual := #VelocitatActual - #Desacceleracio;
                            IF #VelocitatActual <= 10.0 THEN
                                #VelocitatActual := 10.0;
                                #RampaActiva := FALSE; // Fi de la rampa
                            END_IF;
                        ELSE
                            // Accelerar
                            #VelocitatActual := #VelocitatActual + #Acceleracio;
                            IF #VelocitatActual >= 100.0 THEN
                                #VelocitatActual := 100.0;
                            END_IF;
                        END_IF;
                        
                        IF #VelocitatActual <> 0.0 THEN
                            // Conversió més directa i segura
                            #TempsPolsActual := DINT_TO_TIME(REAL_TO_DINT(1000.0 / #VelocitatActual));
                        ELSE
                            #TempsPolsActual := #TempsPolsBase;
                        END_IF;
                    END_IF;
                END_IF;
                
                // Comprovar posició desitjada (SENSE SENSORS DE LÍMIT)
                IF #sPosicioActual_Passos = #PosicioDesitjadaPassos THEN
                    #Estat := 0; // Aturar moviment
                    #MotorPols := FALSE;
                    #EnMoviment := FALSE;
                    #RampaActiva := FALSE;
                    #ComptePasos := 0;
                END_IF;
            END_IF;
            
        ELSE // Error
            #Estat := 0;
            #MotorPols := FALSE;
            #EnMoviment := FALSE;
            #RampaActiva := FALSE;
            #ComptePasos := 0;
    END_CASE;
ELSE
    #MotorPols := FALSE;
    #EnMoviment := FALSE;
    #RampaActiva := FALSE;
    #ComptePasos := 0;
END_IF;                // Control de Rampa
                IF #RampaActiva THEN
                    #ComptePasos := #ComptePasos + 1;
                    IF #ComptePasos >= #PasosPerRampa THEN
                        #ComptePasos := 0;
                        IF #sPosicioActual_Passos < (#PosicioDesitjadaPassos + #CarreraTotal_Passos / 10) AND
                            #sPosicioActual_Passos > (#PosicioDesitjadaPassos - #CarreraTotal_Passos / 10) THEN
                            // Desaccelerar
                            #VelocitatActual := #VelocitatActual - #Desacceleracio;
                            IF #VelocitatActual <= 10.0 THEN
                                #VelocitatActual := 10.0;
                                #RampaActiva := FALSE; // Fi de la rampa
                            END_IF;
                        ELSE
                            // Accelerar
                            #VelocitatActual := #VelocitatActual + #Acceleracio;
                            IF #VelocitatActual >= 100.0 THEN
                                #VelocitatActual := 100.0;
                            END_IF;
                        END_IF;
                        
                        IF #VelocitatActual <> 0.0 THEN
                            // Conversió més directa i segura
                            #TempsPolsActual := DINT_TO_TIME(REAL_TO_DINT(1000.0 / #VelocitatActual));
                        ELSE
                            #TempsPolsActual := #TempsPolsBase;
                        END_IF;
                    END_IF;
                END_IF;
                
                // Comprovar posició desitjada (SENSE SENSORS DE LÍMIT)
                IF #sPosicioActual_Passos = #PosicioDesitjadaPassos THEN
                    #Estat := 0; // Aturar moviment
                    #MotorPols := FALSE;
                    #EnMoviment := FALSE;
                    #RampaActiva := FALSE;
                    #ComptePasos := 0;
                END_IF;
            END_IF;
            
        ELSE // Error
            #Estat := 0;
            #MotorPols := FALSE;
            #EnMoviment := FALSE;
            #RampaActiva := FALSE;
            #ComptePasos := 0;
    END_CASE;
    
ELSE
    #MotorPols := FALSE;
    #EnMoviment := FALSE;
    #RampaActiva := FALSE;
    #ComptePasos := 0;
END_IF;

