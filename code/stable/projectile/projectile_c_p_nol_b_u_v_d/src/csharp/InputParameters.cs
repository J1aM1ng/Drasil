/** \file InputParameters.cs
    \author Samuel J. Crawford, Brooks MacLachlan, and W. Spencer Smith
    \brief Provides the structure for holding input values, the function for reading inputs, and the function for checking the physical constraints on the input
    \note Generated by Drasil v0.1-alpha
*/

using System;
using System.IO;

/** \brief Structure for holding the input values
*/
public class InputParameters {
    public double v_launch;
    public double theta;
    public double p_target;
    
    /** \brief Initializes input object by reading inputs and checking physical constraints on the input
        \param filename name of the input file
    */
    public InputParameters(string filename) {
        this.get_input(filename);
        this.input_constraints();
    }
    
    /** \brief Reads input from a file with the given file name
        \param filename name of the input file
    */
    private void get_input(string filename) {
        StreamReader infile;
        infile = new StreamReader(filename);
        infile.ReadLine();
        this.v_launch = Double.Parse(infile.ReadLine());
        infile.ReadLine();
        this.theta = Double.Parse(infile.ReadLine());
        infile.ReadLine();
        this.p_target = Double.Parse(infile.ReadLine());
        infile.Close();
    }
    
    /** \brief Verifies that input values satisfy the physical constraints
    */
    private void input_constraints() {
        if (!(this.v_launch > 0.0)) {
            Console.Write("Warning: ");
            Console.Write("v_launch has value ");
            Console.Write(this.v_launch);
            Console.Write(", but is suggested to be ");
            Console.Write("above ");
            Console.Write(0.0);
            Console.WriteLine(".");
        }
        if (!(0.0 < this.theta && this.theta < Math.PI / 2.0)) {
            Console.Write("Warning: ");
            Console.Write("theta has value ");
            Console.Write(this.theta);
            Console.Write(", but is suggested to be ");
            Console.Write("between ");
            Console.Write(0.0);
            Console.Write(" and ");
            Console.Write(Math.PI / 2.0);
            Console.Write(" ((pi)/(2))");
            Console.WriteLine(".");
        }
        if (!(this.p_target > 0.0)) {
            Console.Write("Warning: ");
            Console.Write("p_target has value ");
            Console.Write(this.p_target);
            Console.Write(", but is suggested to be ");
            Console.Write("above ");
            Console.Write(0.0);
            Console.WriteLine(".");
        }
    }
}
