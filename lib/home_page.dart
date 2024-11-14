import 'package:expense_tracker_app/bar%20graph/bar_graph.dart';
import 'package:expense_tracker_app/component/my_list_tile.dart';
import 'package:expense_tracker_app/database/expense_database.dart';
import 'package:expense_tracker_app/helper/helper_functions.dart';
import 'package:expense_tracker_app/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //text controllers
  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  //futures to load graph data and monthly total
  Future<Map<String,double>>? _monthlyTotalsFuture;
  Future<double>? _calculateCurrentMonthTotal;
  @override
  void initState() {
    //read db on init startup
    Provider.of<ExpenseDatabase>(context, listen: false).readExpenses();

    //load the futures 
    refreshData();
    super.initState();
  }

  //refresh graph data
  void refreshData(){
    _monthlyTotalsFuture=Provider.of<ExpenseDatabase>(context,listen: false).calculateMonthlyTotals();
    _calculateCurrentMonthTotal = Provider.of<ExpenseDatabase>(context, listen: false).calculateCurrentMonthTotal();
  }

  //open new expense box
  void openNewExpenseBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: Text("New Expense"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //user input -> expense name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: "Name"),
              ),
              //user input -> expense amount
              TextField(
                controller: amountController,
                decoration: const InputDecoration(hintText: "Amount"),
              ),
            ],
          ),
          actions: [
            //cancel button
            _cancelButton(),
            //save button
            _createNewExpenseButton()
          ]),
    );
  }

  
  // open edit box
  void openEditBox(Expense expense){

    //pre fill existing values into textfields
    String existingName = expense.name;
    String existingAmount = expense.amount.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text("Edit Expense"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //user input -> expense name
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: existingName),
              ),
              //user input -> expense amount
              TextField(
                controller: amountController,
                decoration: InputDecoration(hintText: existingAmount),
              ),
            ],
          ),
          actions: [
            //cancel button
            _cancelButton(),
            //save button
            _editExpenseButton(expense),
          ]),
    );
  }
  // open del box
  void openDeleteBox(Expense expense){
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text("Delete Expense"),
          
          actions: [
            //cancel button
            _cancelButton(),
            //save button
            _deleteExpenseButton(expense.id),
          ]),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseDatabase>(
      builder: (context, value, child) {
        //get dates
        int startMonth = value.getStartMonth();
        int startYear = value.getStartYear();
        int currentMonth = DateTime.now().month;
        int currentYear = DateTime.now().year;

        //calc the number of months since the first month
        int monthCount = calculateMonthCount(startYear, startMonth, currentYear, currentMonth);
        // only display the exps for the curr month
        List<Expense> currentMonthExpenses = value.allExpense.where((expense){
          return expense.date.year == currentYear &&
          expense.date.month == currentMonth;
        }).toList();

        //return ui
        return Scaffold(
          backgroundColor: Colors.grey.shade300,
        floatingActionButton: FloatingActionButton(
          onPressed: openNewExpenseBox,
          child: const Icon(Icons.add),
        ),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: FutureBuilder<double>(future: _calculateCurrentMonthTotal, builder: (context, snapshot){
            //loaded
            if(snapshot.connectionState==ConnectionState.done){
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  //amnt total
                  Text('\$${snapshot.data!.toStringAsFixed(2)}'),

                  //month
                  Text(getCurrentMonthName()),
                ],
              );
            }

            //loading
            else{
              return const Text("loading...");
            }
          }),
        ),
        body: SafeArea(
          child: Column(
            children: [
              //graph ui
              SizedBox(
                height: 250,
                child: FutureBuilder(future: _monthlyTotalsFuture, builder: (context, snapshot){
                  //data is loaded
                  if(snapshot.connectionState==ConnectionState.done){
                    Map<String,double> monthlyTotals = snapshot.data ?? {};
                
                    //create the list of monthly summary
                    List<double> monthlySummary = List.generate(monthCount, (index){
                      //calc year month considering startmonth and index

                      int year = startYear + (startMonth + index -1)~/12;
                      int month = (startMonth+index-1)%12+1;

                      //create the key in the format yr-month
                      String yearMonthKey = '$year-$month';

                      //return the total for yr-month or 0.0 if non existent
                      return monthlyTotals[yearMonthKey] ?? 0.0;
                    },);
                
                    return MyBarGraph(monthlySummary: monthlySummary, startMonth: startMonth);
                  }
                  else{
                    return const Center(child: Text("Loading..."),);
                  }
                }),
              ),

              const SizedBox(height: 25,),
              // Expense list ui
              Expanded(
                child: ListView.builder(
                        itemCount: currentMonthExpenses.length,
                        itemBuilder: (context, index){
                         // reverse the list
                         int reversedIndex = currentMonthExpenses.length - 1 - index;
                //get indv exp
                Expense individualExpense = currentMonthExpenses[reversedIndex];
                
                //return list tile ui
                return MyListTile(
                  title: individualExpense.name,
                  trailing: formatAmount(individualExpense.amount),
                  onEditPressed: (context) => openEditBox(individualExpense),
                  onDeletePressed:(context) => openDeleteBox(individualExpense),
                );
                
                          }),
              ),
            ],
          ),
        )
      );
      }
    );
  }

  //cancel button
  Widget _cancelButton() {
    return MaterialButton(
      onPressed: () {
        //pop box
        Navigator.pop(context);

        //clear controllers
        nameController.clear();
        amountController.clear();
      },
      child: const Text('Cancel'),
    );
  }

  //save button -> create a new expense
  Widget _createNewExpenseButton() {
    return MaterialButton(
      onPressed: () async {
        // only save if there is something in the textfield to save
        if (nameController.text.isNotEmpty &&
            amountController.text.isNotEmpty) {
          //pop box
          Navigator.pop(context);
          //create new exp
          Expense newExpense = Expense(
              name: nameController.text,
              amount: convertStringToDouble(amountController.text),
              date: DateTime.now());
          //save to db
          await context.read<ExpenseDatabase>().createNewExpense(newExpense);

          //refresh graph
          refreshData();
          // clear controllers
          nameController.clear();
          amountController.clear();
        }
      },
      child: const Text('Save'),
    );
  }

  //save button -> edit existing expense
  Widget _editExpenseButton(Expense expense) {
    return MaterialButton(
      onPressed: ()async{
        //save as long as at least one textfield has been changed
        if(
          nameController.text.isNotEmpty || amountController.text.isNotEmpty
        ){
          //pop box
          Navigator.pop(context);

          //create a new updated exp
          Expense updatedExpense = Expense(
            name: nameController.text.isNotEmpty?nameController.text:expense.name, 
            amount: amountController.text.isNotEmpty?
            convertStringToDouble(amountController.text):expense.amount, 
            date: DateTime.now()
          );
          //old exp id
          int existingId = expense.id;

          //save in db
          await context.read<ExpenseDatabase>().updateExpense(existingId, updatedExpense);

          //refresh graph
          refreshData();
        }
      },
      child: const Text("Save"),
    );
  }


  //delete button
  Widget _deleteExpenseButton(int id){
    return MaterialButton(
      onPressed: () async{
        //pop box
        Navigator.pop(context);

        //delete expense from db
        await context.read<ExpenseDatabase>().deleteExpense(id);

        //refresh graph
          refreshData();
      },
      child: const Text("Delete"),
    );
  }
}
