can you write every single billing logics in feature sub folder way ? c:\Users\gokul\Desktop\Projects\Enke\eposmob\wikidata\billing @lib/features/billing/
  presentation/pages/billing_page.dart only this page and other files mentioned in it logics need to write @lib/providers/local_product_provider.dart , can split
  in to multiple md files , also can us sub agents , write correctly without lossing any single logics.



  The thing i am doing is i have a billing desktop page which is not good archetecture but most of my users using that screen , so without breaking that screen iam trying to create new screen in mobile in good archetecture , so i need all logics in new archetecture without breaking old screen. then after my tester confirming mobile ui is working with all logics correctly i will start to make my desktop screen archetecture by rewritting it to a new screen , how is the plan ? 



  is it safe to pull from origin/mubashir-dev , can you review changes carefully and make sure none of my feature will broke , first give a review , is the fixes are correct or need any updation also 