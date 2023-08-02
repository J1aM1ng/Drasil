package GlassBR;

/** \file Control.java
    \author Nikitha Krithnan and W. Spencer Smith
    \brief Controls the flow of the program
*/
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;

public class Control {
    
    /** \brief Controls the flow of the program
        \param args List of command-line arguments
    */
    public static void main(String[] args) throws Exception, FileNotFoundException, IOException {
        PrintWriter outfile;
        String filename = args[0];
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'filename' assigned ");
        outfile.print(filename);
        outfile.println(" in module Control");
        outfile.close();
        InputParameters inParams = new InputParameters();
        InputFormat.get_input(filename, inParams);
        DerivedValues.derived_values(inParams);
        InputConstraints.input_constraints(inParams);
        int GTF = Calculations.func_GTF(inParams);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'GTF' assigned ");
        outfile.print(GTF);
        outfile.println(" in module Control");
        outfile.close();
        double J_tol = Calculations.func_J_tol(inParams);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'J_tol' assigned ");
        outfile.print(J_tol);
        outfile.println(" in module Control");
        outfile.close();
        double AR = Calculations.func_AR(inParams);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'AR' assigned ");
        outfile.print(AR);
        outfile.println(" in module Control");
        outfile.close();
        double q = Calculations.func_q(inParams);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'q' assigned ");
        outfile.print(q);
        outfile.println(" in module Control");
        outfile.close();
        double q_hat = Calculations.func_q_hat(inParams, q, GTF);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'q_hat' assigned ");
        outfile.print(q_hat);
        outfile.println(" in module Control");
        outfile.close();
        double q_hat_tol = Calculations.func_q_hat_tol(AR, J_tol);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'q_hat_tol' assigned ");
        outfile.print(q_hat_tol);
        outfile.println(" in module Control");
        outfile.close();
        double J = Calculations.func_J(AR, q_hat);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'J' assigned ");
        outfile.print(J);
        outfile.println(" in module Control");
        outfile.close();
        double NFL = Calculations.func_NFL(inParams, q_hat_tol);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'NFL' assigned ");
        outfile.print(NFL);
        outfile.println(" in module Control");
        outfile.close();
        double B = Calculations.func_B(inParams, J);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'B' assigned ");
        outfile.print(B);
        outfile.println(" in module Control");
        outfile.close();
        double LR = Calculations.func_LR(NFL, GTF);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'LR' assigned ");
        outfile.print(LR);
        outfile.println(" in module Control");
        outfile.close();
        double P_b = Calculations.func_P_b(B);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'P_b' assigned ");
        outfile.print(P_b);
        outfile.println(" in module Control");
        outfile.close();
        boolean isSafeLR = Calculations.func_isSafeLR(LR, q);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'isSafeLR' assigned ");
        outfile.print(isSafeLR);
        outfile.println(" in module Control");
        outfile.close();
        boolean isSafePb = Calculations.func_isSafePb(inParams, P_b);
        outfile = new PrintWriter(new FileWriter(new File("log.txt"), true));
        outfile.print("var 'isSafePb' assigned ");
        outfile.print(isSafePb);
        outfile.println(" in module Control");
        outfile.close();
        OutputFormat.write_output(isSafePb, isSafeLR, P_b, J);
    }
}
