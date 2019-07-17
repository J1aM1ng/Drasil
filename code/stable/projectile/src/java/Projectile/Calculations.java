package Projectile;

/** \file Calculations.java
*/
import java.util.Arrays;
import java.util.BitSet;
import java.util.Scanner;
import java.io.PrintWriter;
import java.io.FileWriter;
import java.io.File;
import java.util.ArrayList;

public class Calculations {
    
    /** \brief Calculates flight duration
        \param inParams No description given
    */
    public static double func_t_flight(InputParameters inParams) throws Exception {
        return ((2 * (inParams.v_launch * Math.sin(inParams.angle))) / 9.8);
    }
    
    /** \brief Calculates landing position
        \param inParams No description given
    */
    public static double func_p_land(InputParameters inParams) throws Exception {
        return ((2 * (Math.pow(inParams.v_launch, 2) * (Math.sin(inParams.angle) * Math.cos(inParams.angle)))) / 9.8);
    }
    
    /** \brief Calculates distance between the target position and the landing position
        \param inParams No description given
        \param p_land landing position
    */
    public static double func_d_offset(InputParameters inParams, double p_land) throws Exception {
        return (p_land - inParams.p_target);
    }
    
    /** \brief Calculates output message as a string
        \param inParams No description given
        \param d_offset distance between the target position and the landing position
    */
    public static String func_s(InputParameters inParams, double d_offset) throws Exception {
        if ((Math.abs((d_offset / inParams.p_target)) < 2.0e-2)) {
            return "The target was hit.";
        }
        else if ((d_offset < 0)) {
            return "The projectile fell short.";
        }
        else if ((d_offset > 0)) {
            return "The projectile went long.";
        }
        else {
            throw new Exception("Undefined case encountered in function func_s");
        }
    }
}

